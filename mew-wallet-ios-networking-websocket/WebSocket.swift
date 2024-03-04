//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 2/21/24.
//

import Foundation
import Network
import mew_wallet_ios_extensions
import mew_wallet_ios_logger

// Proper send
// Proper close
// Path changing?
// Some real tests
// SSL Pinning
// Cleanup
// Docs

extension WebSocket {
  enum Error: Swift.Error {
    case badURL(URL)
  }
  
  enum InternalError: Swift.Error {
    case disconnected
  }
  
  enum ConnectionError: Swift.Error {
    case notReachable
  }
  
  enum State {
    case disconnected
    case pending
    case connected
  }
  
  public enum Event: Sendable, Equatable {
    case connected
    case disconnected
    case viabilityDidChange(_ isViable: Bool)
    case ping
    case pong
    case text(String?)
    case binary(Data?)
    case error(NWError)
    case connectionError(ConnectionError)
  }
  
  fileprivate struct Consumer: Sendable, Equatable {
    let uuid: UUID
    let continuation: AsyncStream<Event>.Continuation
    static func == (lhs: WebSocket.Consumer, rhs: WebSocket.Consumer) -> Bool { lhs.uuid == rhs.uuid }
    
    init(continuation: AsyncStream<Event>.Continuation, termination: (@Sendable (UUID, AsyncStream<Event>.Continuation.Termination) -> Void)?) {
      let uuid = UUID()
      self.uuid = uuid
      
      self.continuation = continuation
      
      continuation.onTermination = { reason in
        termination?(uuid, reason)
      }
    }
  }
}

final class WebSocket: Sendable {
  private let _state = ThreadSafe<State>(.disconnected)
  var state: State { _state.value }
  // Parameters
  private let configuration: WebSocket.Configuration
  private let endpoint: NWEndpoint
  private let parameters: NWParameters
  
  // Connectivity
  private let connectivity: ThreadSafe<Connectivity>
  private let connectivityTask = ThreadSafe<Task<Void, Never>?>(nil)
  
  private let connection = ThreadSafe<NWConnection?>(nil)
  private let connectionQueue: DispatchQueue = .init(label: "mew-wallet-ios-networking-websocket.connectionQeueu", qos: .utility)
  
  private let pingPongTimer = ThreadSafe<Timer?>(nil)
  
  private let consumers = ThreadSafe<[Consumer]>([])
  
  private let disconnectTask = ThreadSafe<Task<Void, Never>?>(nil)
  
  private let listener = ThreadSafe<AsyncStream<Event>.Continuation?>(nil)
  
  /// A convenience initializer that sets up the `WebSocket` connection with optional headers and a delay.
  /// - Parameters:
  ///   - url: The URL of the WebSocket connection to monitor.
  ///   - headers: Extra headers for connection
  ///   - configuration: `WebSocket.Configuration` with connection settings
  convenience init(
    url: URL,
    headers: [(name: String, value: String)] = [],
    configuration: WebSocket.Configuration = .default
  ) throws {
    
    // Parameters
    let webSocketParameters: NWParameters
    let connectivityParameters: NWParameters
    if url.scheme == "wss" || url.scheme == "https" {
      webSocketParameters = NWParameters.tls
      connectivityParameters = NWParameters.tls
    } else {
      webSocketParameters = NWParameters.tcp
      connectivityParameters = NWParameters.tcp
    }
        
    // Options
    let webSocketOptions = NWProtocolWebSocket.Options()
    let connectivityOptions = NWProtocolWebSocket.Options()
    if !headers.isEmpty {
      webSocketOptions.setAdditionalHeaders(headers)
    }
    
    try self.init(
      url: url,
      parameters: (webSocketParameters, connectivityParameters),
      options: (webSocketOptions, connectivityOptions),
      configuration: configuration
    )
    
    
    
    
    
    // Configure endpoint
//    endpoint = .url(url)
    
    // Parameters
    
//    if url.scheme == "ws" {
//      parameters = NWParameters.tcp
//    } else {
//      let tlsOptions = NWProtocolTLS.Options()
//      sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
////        let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
//        sec_protocol_verify_complete(true)
//      }, self.connectionQueue)
//      
//      let options = NWProtocolTCP.Options()
//      options.connectionTimeout = Int(10)
//      
//      parameters = NWParameters(tls: tlsOptions, tcp: options)
//    }
    
    // Options
//    let options = NWProtocolWebSocket.Options()
//    options.autoReplyPing = true
//    if !headers.isEmpty {
//      options.setAdditionalHeaders(headers)
//      options.skipHandshake = true
//    }
//    options.setClientRequestHandler(DispatchQueue.main) { subprotocols, additionalHeaders in
//      Logger.critical(.webSocket, "Request", metadata: [
//        "headers": "\(headers)",
//        "add": "\(additionalHeaders)"
//      ])
//      return .init(status: .accept, subprotocol: nil, additionalHeaders: headers)
//    }
//    parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
  }
  
  /// A convenience initializer that sets up the `WebSocket` connection with the specified URL, parameters, and an optional delay.
  /// - Parameters:
  ///   - url: The URL of the WebSocket connection to monitor.
  ///   - parameters: `NWParameters` used for the WebSocket connection, depending on whether the connection is secure (wss) or not (ws).
  ///   - configuration: `WebSocket.Configuration` with connection settings
  convenience init(
    url: URL,
    parameters: (webSocket: NWParameters, connectivity: NWParameters),
    options: (webSocket: NWProtocolWebSocket.Options, connectivity: NWProtocolWebSocket.Options)? = nil,
    configuration: WebSocket.Configuration = .default
  ) throws {
    let allowedSchemes = ["ws", "wss", "http", "https"]
    guard let scheme = url.scheme,
            allowedSchemes.contains(scheme) else { throw Error.badURL(url) }
    try self.init(endpoint: .url(url), parameters: parameters, options: options, configuration: configuration)
  }
  
  /// The primary initializer that configures the `WebSocket` with the specified URL, parameters, and an optional delay.
  /// - Parameters:
  ///   - endpoint: The `NWEndpoint` of the WebSocket connection to monitor.
  ///   - parameters: `NWParameters` tuple used for the `WebSocket` and `Connectivity` connection, depending on whether the connection is secure (wss) or not (ws).
  ///   - options: `NWProtocolWebSocket.Options` tuple used for `WebSocket` and `Connectivity` connection
  ///   - configuration: `WebSocket.Configuration` with connection settings
  init(
    endpoint: NWEndpoint,
    parameters: (webSocket: NWParameters, connectivity: NWParameters),
    options: (webSocket: NWProtocolWebSocket.Options, connectivity: NWProtocolWebSocket.Options)? = nil,
    configuration: WebSocket.Configuration = .default
  ) throws {
    let webSocketOptions = options?.webSocket ?? NWProtocolWebSocket.Options()
    
    webSocketOptions.autoReplyPing = configuration.autoReplyPing
    parameters.webSocket.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

    self.configuration = configuration
    
    self.connectivity = ThreadSafe(Connectivity(endpoint: endpoint, parameters: parameters.connectivity, options: options?.connectivity, configuration: configuration))
        
    self.endpoint = endpoint
    self.parameters = parameters.webSocket
    Logger.trace(.webSocket, "Initialized", metadata: [
      "endpoint": "\(endpoint)",
      "parameters": "\(parameters)",
      "configuration": "\(configuration)"
    ])
  }
  
  deinit {
    self._discardConsumers()
    Logger.trace(.webSocket, "Deinit", metadata: [
      "endpoint": "\(endpoint)"
    ])
  }
  
  public func connect() -> AsyncStream<Event> {
    self._change(state: .pending, from: .disconnected)
    
    Logger.trace(.webSocket, "New consumer", metadata: [
      "endpoint": "\(endpoint)"
    ])
    return AsyncStream {[weak self] (continuation: AsyncStream<Event>.Continuation) in
      guard let self else {
        Logger.trace(.webSocket, "Consumer discarded", metadata: [
          "endpoint": "\(endpoint)"
        ])
        continuation.finish()
        return
      }
      
      let consumer = self._add(consumer: continuation)
      Logger.trace(.webSocket, "New consumer added", metadata: [
        "endpoint": "\(endpoint)",
        "consumer": "\(consumer.uuid)"
      ])
      
      self._connectIfNeeded()
    }
  }
  
  public func disconnect(_ closeCode: NWProtocolWebSocket.CloseCode = .protocolCode(.normalClosure)) {
    self._process(closeCode: closeCode)
  }
  
  public func send(_ message: String) async throws {
    let data = message.data(using: .utf8)
    let meta = NWProtocolWebSocket.Metadata(opcode: .text)
    let context = NWConnection.ContentContext(identifier: "text", metadata: [meta])
    send(data: data, context: context)
  }
  
  public func send(_ data: Data) async throws {
    let meta = NWProtocolWebSocket.Metadata(opcode: .binary)
    let context = NWConnection.ContentContext(identifier: "binary", metadata: [meta])
    send(data: data, context: context)
  }
  
  public func ping() {
    let meta = NWProtocolWebSocket.Metadata(opcode: .ping)
    meta.setPongHandler(self.connectionQueue) {[weak self] error in
      guard error == nil else { return }
      self?._broadcast(.pong)
    }
    let context = NWConnection.ContentContext(identifier: "ping", metadata: [meta])
    // We have to send some data, otherwise
    send(data: nil, context: context)
  }
  
  public func pong() {
    let meta = NWProtocolWebSocket.Metadata(opcode: .pong)
    let context = NWConnection.ContentContext(identifier: "pong", metadata: [meta])
    send(data: nil, context: context)
  }
  
  private func send(data: Data?, context: NWConnection.ContentContext) {
    self.connection.value?.send(content: data,
                                contentContext: context,
                                isComplete: true,
                                completion: .contentProcessed({/*[weak self]*/ error in
      // check for error? what could be there?
//      debugPrint(">>> sent")
    }))
  }
  
  // MARK: - Private
  
  private func _add(consumer continuation: AsyncStream<Event>.Continuation) -> Consumer {
    let consumer = Consumer(continuation: continuation) {[weak self] uuid, reason in
      guard let self else { return }
      Logger.trace(.webSocket, "Consumer disconnected", metadata: [
        "endpoint": "\(self.endpoint)",
        "uuid": "\(uuid)"
      ])
      
      self._disconnectIfNeeded()
    }
    self.consumers.write { consumers in
      consumers.append(consumer)
    }
    return consumer
  }
  
  private func _remove(consumer: Consumer) {
    self.consumers.write { consumers in
      consumers.removeAll(where: { $0 == consumer })
    }
  }
  
  private func _connectIfNeeded() {
    let result = self.connection.write { connection in
      guard connection == nil else { return false }
      connection = NWConnection(to: self.endpoint, using: self.parameters)
      return true
    }
    
    guard result else { return }
    
    Task {[weak self] in
      guard let self else { return }
      
      await withTaskGroup(of: Void.self) {[weak self] group in
        group.addTask {[weak self] in
          guard let self else { return }
          
          self.connection.value?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            
            Logger.trace(.webSocket, "Connection state changed", metadata: [
              "endpoint": "\(self.endpoint)",
              "state": "\(state)"
            ])
            
            defer {
              if state == .cancelled {
                self._discardConsumers()
              }
            }
            
            if let event = self._process(state: state) {
              Logger.trace(.webSocket, "Processed event", metadata: [
                "endpoint": "\(self.endpoint)",
                "event": "\(event)"
              ])
              let success = self._broadcast(event)
              guard success else { return }
              
              switch event {
              case .connected:
                Task {[weak self] in
                  guard let self else { return }
                  debugPrint("waiting for stream")
                  for await event in self._listenStream() {
                    let success = self._broadcast(event)
                    guard success else { return }
                  }
                }
              case .disconnected:
                return
              default:
                break
              }
            }
          }
          
          self.connection.value?.betterPathUpdateHandler = { [weak self] isAvailable in
            guard let self else { return }
            Logger.trace(.webSocket, "Better path availability changed", metadata: [
              "endpoint": "\(self.endpoint)",
              "available": "\(isAvailable)"
            ])
          }
#if DEBUG
          self.connection.value?.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Logger.trace(.webSocket, "Path changed", metadata: [
              "endpoint": "\(self.endpoint)",
              "available": "\(path)"
            ])
          }
#endif
          self.connection.value?.viabilityUpdateHandler = { [weak self] isViable in
            guard let self else { return }
            Logger.trace(.webSocket, "Viability changed", metadata: [
              "endpoint": "\(self.endpoint)",
              "viable": "\(isViable)"
            ])
            self._broadcast(.viabilityDidChange(isViable))
          }
          
          self.connection.value?.start(queue: connectionQueue)
        }
      }
    }
  }
  
  @discardableResult
  private func _disconnectIfNeeded() -> Bool {
    guard self.consumers.value.isEmpty else { return false }
    Logger.trace(.webSocket, "Termination", metadata: [
      "endpoint": "\(endpoint)",
      "reason": "no consumers"
    ])
    self.listener.write { listener in
      listener?.finish()
      listener = nil
    }
    return true
  }
  
  private func _listenStream() -> AsyncStream<Event> {
    return AsyncStream {[weak self] continuation in
      guard let self else {
        continuation.finish()
        return
      }
      self.listener.value = continuation
      self._listen(continuation)
    }
  }
    
  private func _listen(_ continuation: AsyncStream<Event>.Continuation) {
    /// Start listening for messages over the WebSocket.
    let connection = self.connection.value
    connection?.receiveMessage {[weak self] content, contentContext, isComplete, error in
      guard let self else { return }
      
      if let contentContext,
         let event = self._process(content, context: contentContext) {
        let result = continuation.yield(event)
        if case .terminated = result {
          return
        }
      }
      
      do {
        if let error,
           let event = try self._process(error: error) {
          let result = continuation.yield(event)
          if case .terminated = result {
            return
          }
        }
        
        self._listen(continuation)
      } catch InternalError.disconnected {
        // Do nothing
      } catch {
        // Unknown errors
        self._listen(continuation)
      }
      
//      debugPrint("Listen: \(content) ||| \(contentContext) ||| \(isComplete) ||| \(error)")
//      debugPrint("Listen - content: \(String(data: content ?? Data(), encoding: .utf8))")
//      
//      if let metadata = contentContext?.protocolMetadata.first as? NWProtocolWebSocket.Metadata {
//        debugPrint("Opcode: \(metadata.opcode)")
//      }
//
      
    }
//    connection?.receiveMessage { [weak self] (data, context, _, error) in
//      guard let self = self else {
//        return
//      }
//      
//      if let data = data, !data.isEmpty, let context = context {
//        self.receiveMessage(data: data, context: context)
//      }
//      
//      if let error = error {
//        self.reportErrorOrDisconnection(error)
//      } else {
//        self.listen()
//      }
//    }
  }
  
  private func _process(_ content: Data?, context: NWConnection.ContentContext) -> Event? {
    guard let metadata = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata else { return nil }
    Logger.critical(.webSocket, "\(#function)", metadata: [
      "context": "\(context)",
      "metadata": "\(metadata)",
      "opcode": "\(metadata.opcode)"
    ])
    
    switch metadata.opcode {
    case .binary:
      Logger.trace(.webSocket, "Incoming binary", metadata: [
        "endpoint": "\(endpoint)",
        "size": "\(content?.count ?? .zero)"
      ])
      return .binary(content ?? Data())
    
    case .cont:
      return nil
    
    case .text:
      let string: String?
      if let content {
        string = String(data: content, encoding: .utf8) ?? ""
      } else {
        string = nil
      }
      Logger.trace(.webSocket, "Incoming text", metadata: [
        "endpoint": "\(endpoint)",
        "content": "\(string)"
      ])
      return .text(string)
    
    case .ping:
      return .ping
    
    case .pong:
      return .pong
    
    case .close:
      self._process(closeCode: metadata.closeCode)
      return nil
    
    @unknown default:
      return nil
    }
    
//    guard let metadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata else {
//        return
//    }
//
//    switch metadata.opcode {
//    case .binary:
//        self.delegate?.webSocketDidReceiveMessage(connection: self,
//                                                  data: data)
//    case .cont:
//        //
//        break
//    case .text:
//        guard let string = String(data: data, encoding: .utf8) else {
//            return
//        }
//        self.delegate?.webSocketDidReceiveMessage(connection: self,
//                                                  string: string)
//    case .close:
//        scheduleDisconnectionReporting(closeCode: metadata.closeCode,
//                                       reason: data)
//    case .ping:
//        // SEE `autoReplyPing = true` in `init()`.
//        break
//    case .pong:
//        // SEE `ping()` FOR PONG RECEIVE LOGIC.
//        break
//    @unknown default:
//        fatalError()
//    }
  }
  
  private func _process(error: NWError) throws -> Event? {
    if case let .posix(code) = error {
      switch code {
      case .ENOTCONN where (self.connection.value?.intentionalDisconnection ?? false):
        return nil
      case .ECANCELED where (self.connection.value?.intentionalDisconnection ?? false):
        return nil
      case .ECONNREFUSED:
        Logger.notice(.webSocket, "No connection", metadata: [
          "endpoint": "\(endpoint)",
          "action": "Waiting for connectivity"
        ])
        self.waitForConnectivityAndRestart()
        return .connectionError(.notReachable)
      case .ECONNRESET:
        let result = self._change(state: .pending, from: .connected)
        guard result.changed else { return nil }
        return .disconnected
//        // hmm...
//        let result = self._state.write { state in
//          guard state == .connected else { return false }
//          state = .pending
//          Logger.trace(.webSocket, "Internal state changed", metadata: [
//            "endpoint": "\(endpoint)",
//            "state": "\(state)"
//          ])
//          return true
//        }
//        guard result else { return nil }
        return .disconnected
      case .ETIMEDOUT:
        self._process(closeCode: .protocolCode(.goingAway))
        throw InternalError.disconnected
      case .ENOTCONN:
        self._process(closeCode: .protocolCode(.goingAway))
        throw InternalError.disconnected
      case .ECANCELED:
        self._process(closeCode: .protocolCode(.goingAway))
        throw InternalError.disconnected
      case .ENETDOWN:
        self._process(closeCode: .protocolCode(.goingAway))
        throw InternalError.disconnected
      case .ECONNABORTED:
        self._process(closeCode: .protocolCode(.goingAway))
        throw InternalError.disconnected
        
      default:
        return .error(error)
      }
    }
    return .error(error)
  }
  
  private func _process(closeCode: NWProtocolWebSocket.CloseCode) {
    Logger.trace(.webSocket, "Process close", metadata: [
      "endpoint": "\(endpoint)",
      "code": "\(closeCode)"
    ])
    // schedule close
    // stop processing after that...
    
    // Cancel any existing `disconnectionWorkItem` that was set first
    self.disconnectTask.write {[weak self] task in
      task?.cancel()
      task = Task {[weak self] in
        guard let self else { return }
        do {
          try Task.checkCancellation()
          self._disconnect()
        } catch {}
      }
    }
//    self.disconnectWork = DispatchWorkItem {[weak self] in
//      guard let self else { return }
//      
//      // send ?
//    }
//    
//    
//    sle.fdisconnectionWorkItem?.cancel()
//
//    disconnectionWorkItem = DispatchWorkItem { [weak self] in
//        guard let self = self else { return }
//        self.delegate?.webSocketDidDisconnect(connection: self,
//                                              closeCode: closeCode,
//                                              reason: reason)
//    }
//    
//    connection?.cancel()
//    connection = nil
    // and the rest
    
//    if closeCode == .protocolCode(.normalClosure) {
//        connection?.cancel()
//        scheduleDisconnectionReporting(closeCode: closeCode,
//                                       reason: nil)
//    } else {
//        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
//        metadata.closeCode = closeCode
//        let context = NWConnection.ContentContext(identifier: "closeContext",
//                                                  metadata: [metadata])
//
//        if connection?.state == .ready {
//            // See implementation of `send(data:context:)` for `scheduleDisconnection(closeCode:, reason:)`
//            send(data: nil, context: context)
//        } else {
//            scheduleDisconnectionReporting(closeCode: closeCode, reason: nil)
//        }
//    }
  }
  
  private func _disconnect() {
    Logger.trace(.webSocket, "Internal disconnect triggered", metadata: [
      "endpoint": "\(endpoint)"
    ])
    // send disconnect code
    self.connection.write { connection in
      connection?.cancel()
      connection = nil
    }
  }
  
  private func _discardConsumers() {
    let outdated = self.consumers.write { consumers in
      let outdated = consumers
      consumers.removeAll(keepingCapacity: true)
      return outdated
    }
    guard !outdated.isEmpty else { return }
    outdated.forEach { consumer in
      consumer.continuation.finish()
    }
    
#if DEBUG
    Logger.trace(.webSocket, "Consumers discarded", metadata: [
      "endpoint": "\(endpoint)",
      "active": "\(self.consumers.value.count)"
    ])
#else
    Logger.trace(.webSocket, "Consumers discarded", metadata: [
      "endpoint": "\(endpoint)"
    ])
#endif
  }
  
  // false - means needs disconnect
  @discardableResult
  private func _broadcast(_ event: Event) -> Bool {
    let consumers = self.consumers.value
    guard !consumers.isEmpty else {
      let disconnect = !self._disconnectIfNeeded()
      Logger.trace(.webSocket, "Broadcast failed", metadata: [
        "endpoint": "\(endpoint)",
        "reason": "no consumers",
        "disconnect": "\(disconnect)"
      ])
      return disconnect
    }
    
    // Broadcast and collect outdated streams
    let outdated: [Consumer] = consumers.compactMap { consumer in
      let result = consumer.continuation.yield(event)
      guard case .terminated = result else { return nil }
      return consumer
    }
    
    // If we have outdated - cleanup
    guard !outdated.isEmpty else {
      Logger.trace(.webSocket, "Broadcast sent", metadata: [
        "endpoint": "\(endpoint)",
        "extra": "No outdated",
        "event": "\(event)"
      ])
      return true
    }
    self.consumers.write { consumers in
      consumers.removeAll { outdated.contains($0) }
    }
    let disconnect = !self._disconnectIfNeeded()
    Logger.trace(.webSocket, "Broadcast failed", metadata: [
      "endpoint": "\(endpoint)",
      "reason": "no consumers",
      "disconnect": "\(disconnect)"
    ])
    return disconnect
  }
  
  private func _process(state: NWConnection.State) -> Event? {
      switch state {
      case .ready:
        self._change(state: .connected, from: nil)
        self._startPingPongTimer()
        return .connected
//          isMigratingConnection = false
//          delegate?.webSocketDidConnect(connection: self)
      case .waiting(let error):
        self._change(state: .pending, from: nil)
//        self._state.write { state in
//          state = .pending
//          Logger.trace(.webSocket, "Internal state changed", metadata: [
//            "endpoint": "\(endpoint)",
//            "state": "\(state)"
//          ])
//        }
        self._stopPingPongTimer()
        self.waitForConnectivityAndRestart()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//          self.connection!.restart()
//        }
        return try? self._process(error: error)
//          isMigratingConnection = false
//          reportErrorOrDisconnection(error)
//
//          /// Workaround to prevent loop while reconnecting
//          errorWhileWaitingCount += 1
//          if errorWhileWaitingCount >= errorWhileWaitingLimit {
//              tearDownConnection(error: error)
//              errorWhileWaitingCount = 0
//          }
      case .failed(let error):
        return try? self._process(error: error)
//          errorWhileWaitingCount = 0
//          isMigratingConnection = false
//          tearDownConnection(error: error)
      case .setup:
        return nil
      case .preparing:
        return nil
      case .cancelled:
        let result = self._change(state: .disconnected, from: nil)
        guard result.changed, result.oldState == .connected else { return nil }
        
//        let result = self._state.write { state in
//          let oldState = state
//          guard state != .disconnected else { return false }
//          state = .disconnected
//          Logger.trace(.webSocket, "Internal state changed", metadata: [
//            "endpoint": "\(endpoint)",
//            "state": "\(state)"
//          ])
//          return oldState == .connected
//        }
//        guard result else { return nil }
        return .disconnected
//          errorWhileWaitingCount = 0
//          tearDownConnection(error: nil)
      @unknown default:
        return nil
      }
  }
  
  private func send() {
    
  }
  
  private func waitForConnectivityAndRestart() {
    self.connectivityTask.write {[weak self] task in
      guard task == nil else { return }
      task = Task {[weak self] in
        guard let self else { return }
        defer {
          self.connectivityTask.value = nil
        }
        do {
          try await self.connectivity.value.waitForConnectivity()
          self.connection.value?.restart()
        } catch {
          debugPrint("CANCELLED!")
        }
      }
    }
  }
  
  @discardableResult
  private func _change(state to: State, from: State?) -> (changed: Bool, oldState: State) {
    let result = self._state.write { state in
      if let from {
        // Changing states..
        guard from == state else { return (changed: false, oldState: state) }
      }
      let oldState = state
      guard state != to else { return (changed: false, oldState: state) }
      state = to
      Logger.trace(.webSocket, "Internal state changed", metadata: [
        "endpoint": "\(self.endpoint)",
        "state": "\(state)"
      ])
      return (changed: true, oldState: oldState)
    }
    if result.changed {
      if to == .connected {
        self._startPingPongTimer()
      } else if from == .connected {
        self._stopPingPongTimer()
      }
    }
    return result
  }
  
  private func _startPingPongTimer() {
    guard let delay = self.configuration.pingInterval else { return }
    self.pingPongTimer.write {[weak self] timer in
      guard let self else { return }
      timer?.invalidate()
      timer = Timer(timeInterval: delay, repeats: true) {[weak self] timer in
        self?.ping()
      }
      timer?.tolerance = 0.1
      RunLoop.main.add(timer!, forMode: .common)
    }
  }
  
  private func _stopPingPongTimer() {
    self.pingPongTimer.write { timer in
      timer?.invalidate()
      timer = nil
    }
  }
}




//
//
///// A WebSocket client that manages a socket connection.
//open class NWWebSocket: WebSocketConnection {
//
//    // MARK: - Public properties
//
//    /// The WebSocket connection delegate.
//    public weak var delegate: WebSocketConnectionDelegate?
//
//    /// The default `NWProtocolWebSocket.Options` for a WebSocket connection.
//    ///
//    /// These options specify that the connection automatically replies to Ping messages
//    /// instead of delivering them to the `receiveMessage(data:context:)` method.
//    public static var defaultOptions: NWProtocolWebSocket.Options {
//        let options = NWProtocolWebSocket.Options()
//        options.autoReplyPing = true
//
//        return options
//    }
//
//    private let errorWhileWaitingLimit = 20
//
//    // MARK: - Private properties
//
//    private var connection: NWConnection?
//    private let endpoint: NWEndpoint
//    private let parameters: NWParameters
//    private let connectionQueue: DispatchQueue
//    private var pingTimer: Timer?
//    private var disconnectionWorkItem: DispatchWorkItem?
//    private var isMigratingConnection = false
//    private var errorWhileWaitingCount = 0
//
//    // MARK: - Initialization
//
//    /// Creates a `NWWebSocket` instance which connects to a socket `url` with some configuration `options`.
//    /// - Parameters:
//    ///   - request: The `URLRequest` containing the connection endpoint `URL`.
//    ///   - connectAutomatically: Determines if a connection should occur automatically on initialization.
//    ///                           The default value is `false`.
//    ///   - options: The configuration options for the connection. The default value is `NWWebSocket.defaultOptions`.
//    ///   - connectionQueue: A `DispatchQueue` on which to deliver all connection events. The default value is `.main`.
//    public convenience init(request: URLRequest,
//                            connectAutomatically: Bool = false,
//                            options: NWProtocolWebSocket.Options = NWWebSocket.defaultOptions,
//                            connectionQueue: DispatchQueue = .main) {
//
//        self.init(url: request.url!,
//                  connectAutomatically: connectAutomatically,
//                  connectionQueue: connectionQueue)
//    }
//
//    /// Creates a `NWWebSocket` instance which connects a socket `url` with some configuration `options`.
//    /// - Parameters:
//    ///   - url: The connection endpoint `URL`.
//    ///   - connectAutomatically: Determines if a connection should occur automatically on initialization.
//    ///                           The default value is `false`.
//    ///   - options: The configuration options for the connection. The default value is `NWWebSocket.defaultOptions`.
//    ///   - connectionQueue: A `DispatchQueue` on which to deliver all connection events. The default value is `.main`.
//    public init(url: URL,
//                connectAutomatically: Bool = false,
//                options: NWProtocolWebSocket.Options = NWWebSocket.defaultOptions,
//                connectionQueue: DispatchQueue = .main) {
//
//        endpoint = .url(url)
//
//        if url.scheme == "ws" {
//            parameters = NWParameters.tcp
//        } else {
//            parameters = NWParameters.tls
//        }
//
//        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
//
//        self.connectionQueue = connectionQueue
//
//        if connectAutomatically {
//            connect()
//        }
//    }
//
//    deinit {
//        connection?.intentionalDisconnection = true
//        connection?.cancel()
//    }
//
//    // MARK: - WebSocketConnection conformance
//
//    /// Connect to the WebSocket.
//    open func connect() {
//        if connection == nil {
//            connection = NWConnection(to: endpoint, using: parameters)
//            connection?.stateUpdateHandler = { [weak self] state in
//                self?.stateDidChange(to: state)
//            }
//            connection?.betterPathUpdateHandler = { [weak self] isAvailable in
//                self?.betterPath(isAvailable: isAvailable)
//            }
//            connection?.viabilityUpdateHandler = { [weak self] isViable in
//                self?.viabilityDidChange(isViable: isViable)
//            }
//            listen()
//            connection?.start(queue: connectionQueue)
//        } else if connection?.state != .ready && !isMigratingConnection {
//            connection?.start(queue: connectionQueue)
//        }
//    }
//
//    /// Send a UTF-8 formatted `String` over the WebSocket.
//    /// - Parameter string: The `String` that will be sent.
//    open func send(string: String) {
//        guard let data = string.data(using: .utf8) else {
//            return
//        }
//        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
//        let context = NWConnection.ContentContext(identifier: "textContext",
//                                                  metadata: [metadata])
//
//        send(data: data, context: context)
//    }
//
//    /// Send some `Data` over the WebSocket.
//    /// - Parameter data: The `Data` that will be sent.
//    open func send(data: Data) {
//        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
//        let context = NWConnection.ContentContext(identifier: "binaryContext",
//                                                  metadata: [metadata])
//
//        send(data: data, context: context)
//    }
//
//    /// Start listening for messages over the WebSocket.
//    public func listen() {
//        connection?.receiveMessage { [weak self] (data, context, _, error) in
//            guard let self = self else {
//                return
//            }
//
//            if let data = data, !data.isEmpty, let context = context {
//                self.receiveMessage(data: data, context: context)
//            }
//
//            if let error = error {
//                self.reportErrorOrDisconnection(error)
//            } else {
//                self.listen()
//            }
//        }
//    }
//
//    /// Ping the WebSocket periodically.
//    /// - Parameter interval: The `TimeInterval` (in seconds) with which to ping the server.
//    open func ping(interval: TimeInterval) {
//        pingTimer = .scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
//            guard let self = self else {
//                return
//            }
//
//            self.ping()
//        }
//        pingTimer?.tolerance = 0.01
//    }
//
//    /// Ping the WebSocket once.
//    open func ping() {
//        let metadata = NWProtocolWebSocket.Metadata(opcode: .ping)
//        metadata.setPongHandler(connectionQueue) { [weak self] error in
//            guard let self = self else {
//                return
//            }
//
//            if let error = error {
//                self.reportErrorOrDisconnection(error)
//            } else {
//                self.delegate?.webSocketDidReceivePong(connection: self)
//            }
//        }
//        let context = NWConnection.ContentContext(identifier: "pingContext",
//                                                  metadata: [metadata])
//
//        send(data: "ping".data(using: .utf8), context: context)
//    }
//
//    /// Disconnect from the WebSocket.
//    /// - Parameter closeCode: The code to use when closing the WebSocket connection.
//    open func disconnect(closeCode: NWProtocolWebSocket.CloseCode = .protocolCode(.normalClosure)) {
//        connection?.intentionalDisconnection = true
//
//        // Call `cancel()` directly for a `normalClosure`
//        // (Otherwise send the custom closeCode as a message).
//        if closeCode == .protocolCode(.normalClosure) {
//            connection?.cancel()
//            scheduleDisconnectionReporting(closeCode: closeCode,
//                                           reason: nil)
//        } else {
//            let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
//            metadata.closeCode = closeCode
//            let context = NWConnection.ContentContext(identifier: "closeContext",
//                                                      metadata: [metadata])
//
//            if connection?.state == .ready {
//                // See implementation of `send(data:context:)` for `scheduleDisconnection(closeCode:, reason:)`
//                send(data: nil, context: context)
//            } else {
//                scheduleDisconnectionReporting(closeCode: closeCode, reason: nil)
//            }
//        }
//    }
//
//    // MARK: - Private methods
//
//    // MARK: Connection state changes
//
//    /// The handler for managing changes to the `connection.state` via the `stateUpdateHandler` on a `NWConnection`.
//    /// - Parameter state: The new `NWConnection.State`
//    private func stateDidChange(to state: NWConnection.State) {
//        switch state {
//        case .ready:
//            isMigratingConnection = false
//            delegate?.webSocketDidConnect(connection: self)
//        case .waiting(let error):
//            isMigratingConnection = false
//            reportErrorOrDisconnection(error)
//
//            /// Workaround to prevent loop while reconnecting
//            errorWhileWaitingCount += 1
//            if errorWhileWaitingCount >= errorWhileWaitingLimit {
//                tearDownConnection(error: error)
//                errorWhileWaitingCount = 0
//            }
//        case .failed(let error):
//            errorWhileWaitingCount = 0
//            isMigratingConnection = false
//            tearDownConnection(error: error)
//        case .setup, .preparing:
//            break
//        case .cancelled:
//            errorWhileWaitingCount = 0
//            tearDownConnection(error: nil)
//        @unknown default:
//            fatalError()
//        }
//    }
//
//    /// The handler for informing the `delegate` if there is a better network path available
//    /// - Parameter isAvailable: `true` if a better network path is available.
//    private func betterPath(isAvailable: Bool) {
//        if isAvailable {
//            migrateConnection { [weak self] result in
//                guard let self = self else {
//                    return
//                }
//
//                self.delegate?.webSocketDidAttemptBetterPathMigration(result: result)
//            }
//        }
//    }
//
//    /// The handler for informing the `delegate` if the network connection viability has changed.
//    /// - Parameter isViable: `true` if the network connection is viable.
//    private func viabilityDidChange(isViable: Bool) {
//        delegate?.webSocketViabilityDidChange(connection: self, isViable: isViable)
//    }
//
//    /// Attempts to migrate the active `connection` to a new one.
//    ///
//    /// Migrating can be useful if the active `connection` detects that a better network path has become available.
//    /// - Parameter completionHandler: Returns a `Result`with the new connection if the migration was successful
//    /// or a `NWError` if the migration failed for some reason.
//    private func migrateConnection(completionHandler: @escaping (Result<WebSocketConnection, NWError>) -> Void) {
//        guard !isMigratingConnection else { return }
//        connection?.intentionalDisconnection = true
//        connection?.cancel()
//        isMigratingConnection = true
//        connection = NWConnection(to: endpoint, using: parameters)
//        connection?.stateUpdateHandler = { [weak self] state in
//            self?.stateDidChange(to: state)
//        }
//        connection?.betterPathUpdateHandler = { [weak self] isAvailable in
//            self?.betterPath(isAvailable: isAvailable)
//        }
//        connection?.viabilityUpdateHandler = { [weak self] isViable in
//            self?.viabilityDidChange(isViable: isViable)
//        }
//        listen()
//        connection?.start(queue: connectionQueue)
//    }
//
//    // MARK: Connection data transfer
//
//    /// Receive a WebSocket message, and handle it according to it's metadata.
//    /// - Parameters:
//    ///   - data: The `Data` that was received in the message.
//    ///   - context: `ContentContext` representing the received message, and its metadata.
//    private func receiveMessage(data: Data, context: NWConnection.ContentContext) {
//        guard let metadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata else {
//            return
//        }
//
//        switch metadata.opcode {
//        case .binary:
//            self.delegate?.webSocketDidReceiveMessage(connection: self,
//                                                      data: data)
//        case .cont:
//            //
//            break
//        case .text:
//            guard let string = String(data: data, encoding: .utf8) else {
//                return
//            }
//            self.delegate?.webSocketDidReceiveMessage(connection: self,
//                                                      string: string)
//        case .close:
//            scheduleDisconnectionReporting(closeCode: metadata.closeCode,
//                                           reason: data)
//        case .ping:
//            // SEE `autoReplyPing = true` in `init()`.
//            break
//        case .pong:
//            // SEE `ping()` FOR PONG RECEIVE LOGIC.
//            break
//        @unknown default:
//            fatalError()
//        }
//    }
//
//    /// Send some `Data` over the  active `connection`.
//    /// - Parameters:
//    ///   - data: Some `Data` to send (this should be formatted as binary or UTF-8 encoded text).
//    ///   - context: `ContentContext` representing the message to send, and its metadata.
//    private func send(data: Data?, context: NWConnection.ContentContext) {
//        connection?.send(content: data,
//                         contentContext: context,
//                         isComplete: true,
//                         completion: .contentProcessed({ [weak self] error in
//            guard let self = self else {
//                return
//            }
//
//            // If a connection closure was sent, inform delegate on completion
//            if let socketMetadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata,
//               socketMetadata.opcode == .close {
//                self.scheduleDisconnectionReporting(closeCode: socketMetadata.closeCode,
//                                                    reason: data)
//            }
//
//            if let error = error {
//                self.reportErrorOrDisconnection(error)
//            }
//        }))
//    }
//
//    // MARK: Connection cleanup
//
//    /// Schedules the reporting of a WebSocket disconnection.
//    ///
//    /// The disconnection will be actually reported once the underlying `NWConnection` has been fully torn down.
//    /// - Parameters:
//    ///   - closeCode: A `NWProtocolWebSocket.CloseCode` describing how the connection closed.
//    ///   - reason: Optional extra information explaining the disconnection. (Formatted as UTF-8 encoded `Data`).
//    private func scheduleDisconnectionReporting(closeCode: NWProtocolWebSocket.CloseCode,
//                                                reason: Data?) {
//        // Cancel any existing `disconnectionWorkItem` that was set first
//        disconnectionWorkItem?.cancel()
//
//        disconnectionWorkItem = DispatchWorkItem { [weak self] in
//            guard let self = self else { return }
//            self.delegate?.webSocketDidDisconnect(connection: self,
//                                                  closeCode: closeCode,
//                                                  reason: reason)
//        }
//    }
//
//    /// Tear down the `connection`.
//    ///
//    /// This method should only be called in response to a `connection` which has entered either
//    /// a `cancelled` or `failed` state within the `stateUpdateHandler` closure.
//    /// - Parameter error: error description
//    private func tearDownConnection(error: NWError?) {
//        if let error = error, shouldReportNWError(error) {
//            delegate?.webSocketDidReceiveError(connection: self, error: error)
//        }
//        pingTimer?.invalidate()
//        connection?.cancel()
//        connection = nil
//
//        if let disconnectionWorkItem = disconnectionWorkItem {
//            connectionQueue.async(execute: disconnectionWorkItem)
//        }
//    }
//
//    /// Reports the `error` to the `delegate` (if appropriate) and if it represents an unexpected
//    /// disconnection event, the disconnection will also be reported.
//    /// - Parameter error: The `NWError` to inspect.
//    private func reportErrorOrDisconnection(_ error: NWError) {
//        if shouldReportNWError(error) {
//            delegate?.webSocketDidReceiveError(connection: self, error: error)
//        }
//
//        if isDisconnectionNWError(error) {
//            let reasonData = "The websocket disconnected unexpectedly".data(using: .utf8)
//            scheduleDisconnectionReporting(closeCode: .protocolCode(.goingAway),
//                                           reason: reasonData)
//        }
//    }
//
//    /// Determine if a Network error should be reported.
//    ///
//    /// POSIX errors of either `ENOTCONN` ("Socket is not connected") or
//    /// `ECANCELED` ("Operation canceled") should not be reported if the disconnection was intentional.
//    /// All other errors should be reported.
//    /// - Parameter error: The `NWError` to inspect.
//    /// - Returns: `true` if the error should be reported.
//    private func shouldReportNWError(_ error: NWError) -> Bool {
//        if case let .posix(code) = error,
//           code == .ENOTCONN || code == .ECANCELED,
//           (connection?.intentionalDisconnection ?? false) {
//            return false
//        } else {
//            return true
//        }
//    }
//
//    /// Determine if a Network error represents an unexpected disconnection event.
//    /// - Parameter error: The `NWError` to inspect.
//    /// - Returns: `true` if the error represents an unexpected disconnection event.
//    private func isDisconnectionNWError(_ error: NWError) -> Bool {
//        if case let .posix(code) = error,
//           code == .ETIMEDOUT
//            || code == .ENOTCONN
//            || code == .ECANCELED
//            || code == .ENETDOWN
//            || code == .ECONNABORTED {
//            return true
//        } else {
//            return false
//        }
//    }
//}
//
//
///// Defines a WebSocket connection.
//public protocol WebSocketConnection {
//    /// Connect to the WebSocket.
//    func connect()
//
//    /// Send a UTF-8 formatted `String` over the WebSocket.
//    /// - Parameter string: The `String` that will be sent.
//    func send(string: String)
//
//    /// Send some `Data` over the WebSocket.
//    /// - Parameter data: The `Data` that will be sent.
//    func send(data: Data)
//
//    /// Start listening for messages over the WebSocket.
//    func listen()
//
//    /// Ping the WebSocket periodically.
//    /// - Parameter interval: The `TimeInterval` (in seconds) with which to ping the server.
//    func ping(interval: TimeInterval)
//
//    /// Ping the WebSocket once.
//    func ping()
//
//    /// Disconnect from the WebSocket.
//    /// - Parameter closeCode: The code to use when closing the WebSocket connection.
//    func disconnect(closeCode: NWProtocolWebSocket.CloseCode)
//
//    /// The WebSocket connection delegate.
//    var delegate: WebSocketConnectionDelegate? { get set }
//}
//
///// Defines a delegate for a WebSocket connection.
//public protocol WebSocketConnectionDelegate: AnyObject {
//    /// Tells the delegate that the WebSocket did connect successfully.
//    /// - Parameter connection: The active `WebSocketConnection`.
//    func webSocketDidConnect(connection: WebSocketConnection)
//
//    /// Tells the delegate that the WebSocket did disconnect.
//    /// - Parameters:
//    ///   - connection: The `WebSocketConnection` that disconnected.
//    ///   - closeCode: A `NWProtocolWebSocket.CloseCode` describing how the connection closed.
//    ///   - reason: Optional extra information explaining the disconnection. (Formatted as UTF-8 encoded `Data`).
//    func webSocketDidDisconnect(connection: WebSocketConnection,
//                                closeCode: NWProtocolWebSocket.CloseCode,
//                                reason: Data?)
//
//    /// Tells the delegate that the WebSocket connection viability has changed.
//    ///
//    /// An example scenario of when this method would be called is a Wi-Fi connection being lost due to a device
//    /// moving out of signal range, and then the method would be called again once the device moved back in range.
//    /// - Parameters:
//    ///   - connection: The `WebSocketConnection` whose viability has changed.
//    ///   - isViable: A `Bool` indicating if the connection is viable or not.
//    func webSocketViabilityDidChange(connection: WebSocketConnection,
//                                     isViable: Bool)
//
//    /// Tells the delegate that the WebSocket has attempted a migration based on a better network path becoming available.
//    ///
//    /// An example of when this method would be called is if a device is using a cellular connection, and a Wi-Fi connection
//    /// becomes available. This method will also be called if a device loses a Wi-Fi connection, and a cellular connection is available.
//    /// - Parameter result: A `Result` containing the `WebSocketConnection` if the migration was successful, or a
//    /// `NWError` if the migration failed for some reason.
//    func webSocketDidAttemptBetterPathMigration(result: Result<WebSocketConnection, NWError>)
//
//    /// Tells the delegate that the WebSocket received an error.
//    ///
//    /// An error received by a WebSocket is not necessarily fatal.
//    /// - Parameters:
//    ///   - connection: The `WebSocketConnection` that received an error.
//    ///   - error: The `NWError` that was received.
//    func webSocketDidReceiveError(connection: WebSocketConnection,
//                                  error: NWError)
//
//    /// Tells the delegate that the WebSocket received a 'pong' from the server.
//    /// - Parameter connection: The active `WebSocketConnection`.
//    func webSocketDidReceivePong(connection: WebSocketConnection)
//
//    /// Tells the delegate that the WebSocket received a `String` message.
//    /// - Parameters:
//    ///   - connection: The active `WebSocketConnection`.
//    ///   - string: The UTF-8 formatted `String` that was received.
//    func webSocketDidReceiveMessage(connection: WebSocketConnection,
//                                    string: String)
//
//    /// Tells the delegate that the WebSocket received a binary `Data` message.
//    /// - Parameters:
//    ///   - connection: The active `WebSocketConnection`.
//    ///   - data: The `Data` that was received.
//    func webSocketDidReceiveMessage(connection: WebSocketConnection,
//                                    data: Data)
//}

import Network

fileprivate var _intentionalDisconnection: Bool = false

internal extension NWConnection {

    var intentionalDisconnection: Bool {
        get {
            return _intentionalDisconnection
        }
        set {
            _intentionalDisconnection = newValue
        }
    }
}


//
//import Foundation
//import Network
//
//// Define the types of commands for your game to use.
//enum GameMessageType: UInt32 {
//  case invalid = 0
//  case selectedCharacter = 1
//  case move = 2
//}

// Create a class that implements a framing protocol.
//class GameProtocol: NWProtocolFramerImplementation {
//  let framer = NWProtocolWebSocket.definition
//
//  // Create a global definition of your game protocol to add to connections.
//  static let definition = NWProtocolFramer.Definition(implementation: GameProtocol.self)
//
//  // Set a name for your protocol for use in debugging.
//  static var label: String { return "TicTacToe" }
//
//  // Set the default behavior for most framing protocol functions.
//  required init(framer: NWProtocolFramer.Instance) {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)",
//    ])
//  }
//  func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)",
//    ])
//    return .willMarkReady
//  }
//  func wakeup(framer: NWProtocolFramer.Instance) {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)",
//    ])
//  }
//  func stop(framer: NWProtocolFramer.Instance) -> Bool {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)",
//    ])
//    return true
//  }
//  func cleanup(framer: NWProtocolFramer.Instance) {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)"
//      ]
//    )
//  }
//
//  // Whenever the application sends a message, add your protocol header and forward the bytes.
//  func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)",
//      "message": "\(message)",
//      "length": "\(messageLength)",
//      "isComplete": "\(isComplete)"
//    ])
//    // Extract the type of message.
//    let type = message.gameMessageType
//
//    // Create a header using the type and length.
//    let header = GameProtocolHeader(type: type.rawValue, length: UInt32(messageLength))
//
//    // Write the header.
//    framer.writeOutput(data: header.encodedData)
//
//    // Ask the connection to insert the content of the app message after your header.
//    do {
//      try framer.writeOutputNoCopy(length: messageLength)
//    } catch let error {
//      print("Hit error writing \(error)")
//    }
//  }
//
//  // Whenever new bytes are available to read, try to parse out your message format.
//  func handleInput(framer: NWProtocolFramer.Instance) -> Int {
//    Logger.critical(.webSocket, "\(#function)", metadata: [
//      "framer": "\(framer)",
//    ])
//    while true {
//      // Try to read out a single header.
//      var tempHeader: GameProtocolHeader? = nil
//      let headerSize = GameProtocolHeader.encodedSize
//      let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
//                       maximumLength: headerSize) { (buffer, isComplete) -> Int in
//        guard let buffer = buffer else {
//          return 0
//        }
//        if buffer.count < headerSize {
//          return 0
//        }
//        tempHeader = GameProtocolHeader(buffer)
//        return headerSize
//      }
//
//            // If you can't parse out a complete header, stop parsing and return headerSize,
//            // which asks for that many more bytes.
//      guard parsed, let header = tempHeader else {
//        return headerSize
//      }
//
//      // Create an object to deliver the message.
//      var messageType = GameMessageType.invalid
//      if let parsedMessageType = GameMessageType(rawValue: header.type) {
//        messageType = parsedMessageType
//      }
//      let message = NWProtocolFramer.Message(gameMessageType: messageType)
//
//      // Deliver the body of the message, along with the message object.
//      if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
//        return 0
//      }
//    }
//  }
//}

//// Extend framer messages to handle storing your command types in the message metadata.
//extension NWProtocolFramer.Message {
//  convenience init(gameMessageType: GameMessageType) {
//    self.init(definition: GameProtocol.definition)
//    self["GameMessageType"] = gameMessageType
//  }
//
//  var gameMessageType: GameMessageType {
//    if let type = self["GameMessageType"] as? GameMessageType {
//      return type
//    } else {
//      return .invalid
//    }
//  }
//}
//
//// Define a protocol header structure to help encode and decode bytes.
//struct GameProtocolHeader: Codable {
//  let type: UInt32
//  let length: UInt32
//
//  init(type: UInt32, length: UInt32) {
//    self.type = type
//    self.length = length
//  }
//
//  init(_ buffer: UnsafeMutableRawBufferPointer) {
//    var tempType: UInt32 = 0
//    var tempLength: UInt32 = 0
//    withUnsafeMutableBytes(of: &tempType) { typePtr in
//      typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
//                              count: MemoryLayout<UInt32>.size))
//    }
//    withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
//      lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
//                                count: MemoryLayout<UInt32>.size))
//    }
//    type = tempType
//    length = tempLength
//  }
//
//  var encodedData: Data {
//    var tempType = type
//    var tempLength = length
//    var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
//    data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
//    return data
//  }
//
//  static var encodedSize: Int {
//    return MemoryLayout<UInt32>.size * 2
//  }
//}
