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

// Path changing?

/// `WebSocket` is a public final class designed to handle WebSocket connections in a thread-safe manner, supporting both secure (wss) and insecure (ws) protocols.
/// It provides functionality for connecting to a WebSocket server, sending and receiving messages, and handling ping/pong messages for connection keep-alive.
/// TODO: Currently `WebSocket` doesn't handle `betterPathUpdateHandler`
public final class WebSocket: Sendable {
  /// State
  
  /// A thread-safe wrapper for the connection state.
  private let _state = ThreadSafe<State>(.disconnected)
  
  /// Public read-only access to the current state of the WebSocket connection.
  public var state: State { _state.value }
  
  /// Parameters
  
  /// Configuration settings for the WebSocket connection.
  private let configuration: WebSocket.Configuration
  
  /// The endpoint for the WebSocket connection, supporting both URL and host/port-based connections.
  private let endpoint: NWEndpoint
  
  /// Network parameters for the WebSocket connection, including protocol-specific options for TCP, TLS, and WebSocket protocols.
  private let parameters: NWParameters
  
  /// Connectivity
  
  /// A thread-safe wrapper for tracking the connectivity status of the WebSocket.
  private let connectivity: ThreadSafe<Connectivity>
  
  /// A thread-safe wrapper for a task that manages the WebSocket connection process.
  private let connectivityTask = ThreadSafe<Task<Void, Never>?>(nil)

  /// Connection
  
  /// A thread-safe reference to the network connection used by the WebSocket.
  private let connection = ThreadSafe<NWConnection?>(nil)
  
  /// A thread-safe reference to the connection stream listener. Usually it's nil, non nil value means connection is on hold
  private let connectionStream = ThreadSafe<AsyncStream<Event>.Continuation?>(nil)
  
  /// An optional `TLSPinner` instance for handling TLS certificate pinning, enhancing security for secure WebSocket connections.
  private let pinner: WebSocket.TLSPinner?
  
  /// The dispatch queue used for connection-related operations, ensuring thread safety.
  private let connectionQueue: DispatchQueue = .init(label: "mew-wallet-ios-networking-websocket.connectionQeueu", qos: .utility)
  
  /// A thread-safe reference to an `AsyncStream` continuation for broadcasting WebSocket events to listeners.
  private let listener = ThreadSafe<AsyncStream<Event>.Continuation?>(nil)
  /// A thread-safe reference to an async `Task` for broadcasting WebSocket events to listeners
  private let listenerTask = ThreadSafe<Task<Void, Never>?>(nil)
  
  /// Ping pong
  
  /// A thread-safe timer for managing ping/pong message intervals to keep the WebSocket connection alive.
  private let pingPongTimer = ThreadSafe<Timer?>(nil)
  
  /// Clients
  
  /// A thread-safe list of consumers (listeners) for WebSocket events.
  private let consumers = ThreadSafe<[WebSocket.Consumer]>([])
  
  /// Disconnect
  
  /// A thread-safe wrapper for a task that handles the disconnection process.
  private let disconnectTask = ThreadSafe<Task<Void, Never>?>(nil)
  
  /// A thread-safe wrapper for an `intentionalDisconnect` bool value
  private let _intentionalDisconnect = ThreadSafe<Bool>(false)
  
  /// A thread-safe wrapper for pending send requests
  private let _pendingRequests = ThreadSafe<[UUID: CheckedContinuation<Void, any Error>]>([:])
  
  // MARK: - Lifecycle
  
  /// Initializes a `WebSocket` connection using a URL and optional headers.
  /// - Parameters:
  ///   - url: The URL for the WebSocket connection.
  ///   - headers: Additional headers to include in the WebSocket handshake.
  ///   - configuration: Configuration settings for the WebSocket connection.
  public convenience init(
    url: URL,
    headers: [(name: String, value: String)],
    configuration: WebSocket.Configuration = .default
  ) throws {
    // Options
    let webSocketOptions = NWProtocolWebSocket.Options()
    let connectivityOptions = NWProtocolWebSocket.Options()
    if !headers.isEmpty {
      webSocketOptions.setAdditionalHeaders(headers)
    }
    
    try self.init(
      url: url,
      options: ([webSocketOptions], [connectivityOptions]),
      configuration: configuration
    )
  }
  
  /// Initializes a `WebSocket` connection using a URL, optional protocol options for WebSocket and connectivity, and configuration.
  /// - Parameters:
  ///   - url: The URL for the WebSocket connection.
  ///   - options: Optional protocol options for customizing the WebSocket and connectivity protocols.
  ///   - configuration: Configuration settings for the WebSocket connection.
  public convenience init(
    url: URL,
    options: (webSocket: [NWProtocolOptions], connectivity: [NWProtocolOptions])? = nil,
    configuration: WebSocket.Configuration = .default
  ) throws {
    try self.init(endpoint: .url(url), options: options, configuration: configuration)
  }
  
  /// Initializes a `WebSocket` connection with detailed configuration including endpoint, protocol options, and connection settings.
  /// This is the primary initializer that sets up the internal state and prepares the connection.
  /// - Parameters:
  ///   - endpoint: The network endpoint (URL or host and port) to connect to.
  ///   - options: Optional tuple containing arrays of `NWProtocolOptions` for WebSocket and connectivity configuration.
  ///   - configuration: Configuration settings for the WebSocket connection, defining behavior like ping intervals, TLS settings, and more.
  public init(
    endpoint: NWEndpoint,
    options: (webSocket: [NWProtocolOptions], connectivity: [NWProtocolOptions])? = nil,
    configuration: WebSocket.Configuration = .default
  ) throws {
    // Setup and initialization logic, including TLS pinner setup, is omitted for brevity.
    
    // TLS Protocol
    var protocolTLSOptions = (options?.webSocket.first(where: { $0 is NWProtocolTLS.Options }) as? NWProtocolTLS.Options)
    switch configuration.tls {
    case .disabled:
      // We have nothing to do here, just use what we have
      self.pinner = nil
    case .unpinned:
      // Make sure we have options
      protocolTLSOptions = protocolTLSOptions ?? NWProtocolTLS.Options()
      self.pinner = nil
    case .pinned(let domain, let allowSelfSigned):
      
      // Make sure we have options and pinning is enabled
      protocolTLSOptions = protocolTLSOptions ?? NWProtocolTLS.Options()
      self.pinner = TLSPinner(domain: domain, allowSelfSigned: allowSelfSigned, endpoint: endpoint, options: protocolTLSOptions!, queue: self.connectionQueue)
    }
    
    // TCP Protocol
    let protocolTCPOptions = (options?.webSocket.first(where: { $0 is NWProtocolTCP.Options }) as? NWProtocolTCP.Options) ?? NWProtocolTCP.Options()
    protocolTCPOptions.connectionTimeout = 5
    protocolTCPOptions.persistTimeout = 5
    
    // WebSocket Protocol
    let protocolWebSocketOptions = (options?.webSocket.first(where: { $0 is NWProtocolWebSocket.Options }) as? NWProtocolWebSocket.Options) ?? NWProtocolWebSocket.Options()
    protocolWebSocketOptions.autoReplyPing = configuration.autoReplyPing
    
    // Prepare NWParameters
    let parametersWebSocket = NWParameters(tls: protocolTLSOptions, tcp: protocolTCPOptions)
    
    // Add WebSocket to NWParameters
    parametersWebSocket.defaultProtocolStack.applicationProtocols.insert(protocolWebSocketOptions, at: 0)
    
    // Create Connectivity
    self.connectivity = try ThreadSafe(Connectivity(endpoint: endpoint, options: options?.connectivity ?? [], configuration: configuration))
    
    // Set parameters
    self.endpoint = endpoint
    self.parameters = parametersWebSocket
    self.configuration = configuration
    
    Logger.trace(.webSocket, "Initialized", metadata: [
      "endpoint": "\(self.endpoint)",
      "parameters": "\(self.parameters)",
      "configuration": "\(self.configuration)"
    ])
  }
  
  deinit {
    // Cleanup code to ensure resources are properly released when the WebSocket instance is deallocated.
    self._discardConsumers()
    Logger.trace(.webSocket, "Deinit", metadata: [
      "endpoint": "\(self.endpoint)"
    ])
  }
  
  // MARK: - Connect
  
  /// Initiates the connection to the WebSocket server and returns an `AsyncStream` of events.
  /// This function manages the connection lifecycle, including reconnection handling and event broadcasting.
  /// - Returns: An `AsyncStream<Event>` that emits WebSocket events such as connected, disconnected, received messages, etc.
  public func connect() -> AsyncStream<Event> {
    // Connection initiation and event stream setup logic is omitted for brevity.
    self._change(state: .pending, from: .disconnected)
    
    Logger.trace(.webSocket, "New consumer", metadata: [
      "endpoint": "\(self.endpoint)"
    ])
    return AsyncStream {[weak self] (continuation: AsyncStream<Event>.Continuation) in
      guard let self else {
        Logger.trace(.webSocket, "Consumer discarded on connect")
        continuation.finish()
        return
      }
      
      let consumer = self._add(consumer: continuation)
      Logger.trace(.webSocket, "New consumer added", metadata: [
        "endpoint": "\(self.endpoint)",
        "consumer": "\(consumer.uuid)"
      ])
      
      self._connectIfNeeded()
    }
  }
  
  // MARK: - Send
  
  /// Sends a text message to the WebSocket server asynchronously. Waits for successful sending or throws an error
  /// - Parameter message: The text message to send
  public func send(_ message: String) async throws {
    let data = message.data(using: .utf8)
    try await send(data: data, opcode: .text)
  }
  
  /// Sends a text message to the WebSocket server asynchronously.
  /// - Parameter message: The text message to send
  public func send(_ message: String) {
    let data = message.data(using: .utf8)
    send(data: data, opcode: .text)
  }
  
  /// Sends a binary message to the WebSocket server asynchronously. Waits for successful sending or throws an error
  /// - Parameter data: The binary data to send.
  public func send(_ data: Data) async throws {
    try await send(data: data, opcode: .binary)
  }
  
  /// Sends a binary message to the WebSocket server asynchronously.
  /// - Parameter data: The binary data to send.
  public func send(_ data: Data) {
    send(data: data, opcode: .binary)
  }
  
  /// Sends a ping message to the WebSocket server to keep the connection alive.
  public func ping() {
    let meta = NWProtocolWebSocket.Metadata(opcode: .ping)
    meta.setPongHandler(self.connectionQueue) {[weak self] error in
      guard error == nil else { return }
      self?._broadcast(.pong)
    }
    send(data: nil, opcode: .ping, meta: meta)
  }
  
  /// Responds to a ping message from the server with a pong message.
  /// This method automatically handles ping messages according to the WebSocket protocol.
  public func pong() {
    send(data: nil, opcode: .pong)
  }
  
  // MARK: - Disconnect
  
  /// Disconnects the WebSocket connection with an optional close code.
  /// Properly closes the connection according to the WebSocket protocol.
  /// - Parameter closeCode: The WebSocket close code indicating the reason for disconnection.
  public func disconnect(_ closeCode: NWProtocolWebSocket.CloseCode = .protocolCode(.normalClosure)) {
    self._intentionalDisconnect.value = true
    // Proper close
    self._process(closeCode: closeCode)
  }
  
  // MARK: - Private
  
  // MARK: - Send
  
  /// A helper method to asynchronously send data over the WebSocket connection.
  /// - Parameters:
  ///   - data: The data to send. This could be nil if sending control frames like ping/pong.
  ///   - opcode: The opcode indicating the type of data being sent (text, binary, ping, pong, etc.).
  ///   - meta: Optional metadata associated with the data being sent.
  @inline(__always)
  private func send(data: Data?, opcode: NWProtocolWebSocket.Opcode, meta: NWProtocolWebSocket.Metadata? = nil) async throws {
    let meta = meta ?? NWProtocolWebSocket.Metadata(opcode: opcode)
    let context = NWConnection.ContentContext(identifier: "\(meta.opcode)", metadata: [meta])
    try await send(data: data, context: context)
  }
  
  /// A helper method to asynchronously send data over the WebSocket connection.
  /// - Parameters:
  ///   - data: The data to send. This could be nil if sending control frames like ping/pong.
  ///   - opcode: The opcode indicating the type of data being sent (text, binary, ping, pong, etc.).
  ///   - meta: Optional metadata associated with the data being sent.
  @inline(__always)
  private func send(data: Data?, opcode: NWProtocolWebSocket.Opcode, meta: NWProtocolWebSocket.Metadata? = nil) {
    let meta = meta ?? NWProtocolWebSocket.Metadata(opcode: opcode)
    let context = NWConnection.ContentContext(identifier: "\(meta.opcode)", metadata: [meta])
    send(data: data, context: context)
  }
  
  /// Handles the low-level details of sending data over the network.
  /// This method ensures that messages are only sent when the connection is in the connected state.
  /// - Parameters:
  ///   - data: The data to send.
  ///   - context: The content context for the data being sent, including metadata like the opcode.
  @inline(__always)
  private func send(data: Data?, context: NWConnection.ContentContext) async throws {
    guard self._state.value == .connected else {
      throw ConnectionError.notReachable
    }
    try await withCheckedThrowingContinuation {[weak self] continuation in
      guard let self, let connection = self.connection.value else {
        continuation.resume()
        return
      }
      let id = UUID()
      self._pendingRequests.write { pendings in
        pendings[id] = continuation
      }
      connection.send(content: data,
                      contentContext: context,
                      isComplete: true,
                      completion: .contentProcessed({ error in
        self._pendingRequests.write { pendings in
          pendings.removeValue(forKey: id)
        }
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }))
    }
  }
  
  /// Handles the low-level details of sending data over the network.
  /// This method ensures that messages are only sent when the connection is in the connected state.
  /// - Parameters:
  ///   - data: The data to send.
  ///   - context: The content context for the data being sent, including metadata like the opcode.
  @inline(__always)
  private func send(data: Data?, context: NWConnection.ContentContext) {
    self.connection.value?.send(
      content: data,
      contentContext: context,
      isComplete: true,
      completion: .contentProcessed({ _ in }))
  }
  
  // MARK: - Consumers
  
  /// Adds a new consumer for WebSocket events.
  /// This method registers a continuation from an `AsyncStream` to the list of active consumers.
  /// - Parameter continuation: The `AsyncStream<Event>.Continuation` that will receive WebSocket events.
  /// - Returns: A `Consumer` object representing the newly added consumer.
  private func _add(consumer continuation: AsyncStream<Event>.Continuation) -> Consumer {
    let consumer = Consumer(continuation: continuation) {[weak self] consumer, reason in
      guard let self else { return }
      Logger.trace(.webSocket, "Consumer disconnected", metadata: [
        "endpoint": "\(self.endpoint)",
        "uuid": "\(consumer.uuid)",
        "reason": "\(reason)"
      ])
      
      self._remove(consumer: consumer)
      self._disconnectIfNeeded()
    }
    self.consumers.write { consumers in
      consumers.append(consumer)
    }
    return consumer
  }
  
  /// Removes a consumer from the list of active consumers.
  /// This method is typically called when a consumer no longer wishes to receive WebSocket events or when its associated stream is finished.
  /// - Parameter consumer: The `Consumer` object to be removed.
  private func _remove(consumer: Consumer) {
    self.consumers.write { consumers in
      consumers.removeAll(where: { $0 == consumer })
    }
  }
  
  /// Discards all active consumers of the WebSocket events.
  /// This method is typically called as part of the disconnection process to ensure that all event streams are properly terminated.
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
      "endpoint": "\(self.endpoint)",
      "active": "\(self.consumers.value.count)"
    ])
#else
    Logger.trace(.webSocket, "Consumers discarded", metadata: [
      "endpoint": "\(self.endpoint)"
    ])
#endif
  }
  
  // MARK: - Connection
  
  /// Attempts to establish a WebSocket connection if not already connected or currently trying to connect.
  /// This method checks the current state and initiates a connection sequence if appropriate.
  private func _connectIfNeeded() {
    let result = self.connection.write {[weak self] connection in
      guard let self, connection == nil else { return false }
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
                listenerTask.write {[weak self] task in
                  guard task == nil else { return }
                  task = Task {[weak self] in
                    guard let self else { return }
                    Logger.trace(.webSocket, "Waiting for stream")
                    for await event in self._listenStream() {
                      let success = self._broadcast(event)
                      guard success else {
                        return
                      }
                    }
                    self.listenerTask.value = nil
                    Logger.trace(.webSocket, "Stream finished")
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
  
  private func _restartConnection() {
    self.connection.write {[weak self] connection in
      guard let self else { return }
      guard let outdated = connection else { return }
      
      connection = NWConnection(to: self.endpoint, using: self.parameters)
      connection?.stateUpdateHandler = outdated.stateUpdateHandler
      connection?.betterPathUpdateHandler = outdated.betterPathUpdateHandler
      connection?.pathUpdateHandler = outdated.pathUpdateHandler
      connection?.viabilityUpdateHandler = outdated.viabilityUpdateHandler
      
      outdated.stateUpdateHandler = nil
      outdated.betterPathUpdateHandler = nil
      outdated.pathUpdateHandler = nil
      outdated.viabilityUpdateHandler = nil
      outdated.forceCancel()
      
      connection?.start(queue: self.connectionQueue)
    }
  }
  
  // MARK: - Listening
  
  /// Creates and returns an `AsyncStream<Event>` for receiving WebSocket events.
  /// This method sets up a stream that will listen for messages and other events from the WebSocket connection and deliver them to consumers.
  /// - Returns: An `AsyncStream<Event>` that emits WebSocket events.
  private func _listenStream() -> AsyncStream<Event> {
    Logger.trace(.webSocket, "Start listener")
    return AsyncStream {[weak self] continuation in
      guard let self else {
        continuation.finish()
        return
      }
      self.listener.value = continuation
      self._listen(continuation)
    }
  }
  
  /// Listens for WebSocket messages and delivers them to the active continuation.
  /// This recursive method listens for incoming data from the WebSocket connection and, upon receiving a message, decodes it and forwards it to the continuation.
  /// - Parameter continuation: The `AsyncStream<Event>.Continuation` that will receive decoded messages and events.
  private func _listen(_ continuation: AsyncStream<Event>.Continuation) {
    /// Start listening for messages over the WebSocket.
    guard !self._intentionalDisconnect.value else {
      return
    }
    let connection = self.connection.value
    connection?.receiveMessage {[weak self] content, contentContext, isComplete, error in
      guard let self else { return }
      guard !self._intentionalDisconnect.value else { return }
      
      if let contentContext,
         let event = self._process(content: content, context: contentContext) {
        let result = continuation.yield(event)
        if case .terminated = result { return }
      }
      
      do {
        if let error,
           let event = try self._process(error: error) {
          let result = continuation.yield(event)
          if case .terminated = result { return }
        }
        
        self._listen(continuation)
      } catch InternalError.disconnected {
        // Do nothing, breaking connection
      } catch InternalError.onHold {
      } catch {
        // Unknown errors
        Logger.trace(.webSocket, "Unknown error in listener", metadata: [
          "error": "\(error)"
        ])
        self._listen(continuation)
      }
    }
  }
  
  // MARK: - Broadcasting
  
  /// Broadcasts events to all registered consumers of the WebSocket.
  /// This method ensures that all listeners are notified of events such as messages, connection state changes, etc.
  /// - Parameter event: The event to broadcast.
  /// - Returns: A Boolean indicating whether the broadcast was successful and if there are active listeners. `false` == WebSocket will be disconnection
  @discardableResult
  private func _broadcast(_ event: Event) -> Bool {
    let consumers = self.consumers.value
    guard !consumers.isEmpty else {
      let disconnect = !self._disconnectIfNeeded()
      Logger.trace(.webSocket, "Broadcast failed", metadata: [
        "event": "\(event)",
        "endpoint": "\(self.endpoint)",
        "reason": "no consumers",
        "disconnect": "\(!disconnect)"
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
        "endpoint": "\(self.endpoint)",
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
      "event": "\(event)",
      "endpoint": "\(self.endpoint)",
      "reason": "no consumers",
      "disconnect": "\(!disconnect)"
    ])
    return disconnect
  }
  
  // MARK: - Processing
  
  /// Processes and handles incoming messages, converting raw data into consumable events for the client.
  /// - Parameters:
  ///   - content: The raw data received from the server.
  ///   - context: The context of the received message, including metadata and opcode.
  private func _process(content: Data?, context: NWConnection.ContentContext) -> Event? {
    guard let metadata = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata else { return nil }
    Logger.trace(.webSocket, "\(#function)", metadata: [
      "context": "\(context)",
      "metadata": "\(metadata)",
      "opcode": "\(metadata.opcode)"
    ])
    
    switch metadata.opcode {
    case .binary:
      Logger.trace(.webSocket, "Incoming binary", metadata: [
        "endpoint": "\(self.endpoint)",
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
        "endpoint": "\(self.endpoint)",
        "content": "\(String(describing: string))"
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
  }
  
  /// Processes errors encountered during the WebSocket connection lifecycle.
  /// - Parameter error: The error that occurred.
  /// - Returns: An optional `Event` representing the error, for broadcasting to consumers.
  private func _process(error: NWError) throws -> Event? {
    switch error {
    case .posix(let code):
      switch code {
        //      case .ENOTCONN where intentional disconnection // Better path case?
        //        return nil
        //      case .ECANCELED where intentional disconnection // Better path case?
        //        return nil
      case .ECONNREFUSED, .ETIMEDOUT, .ENOTCONN, .ENETDOWN:
        Logger.notice(.webSocket, "No connection", metadata: [
          "endpoint": "\(self.endpoint)",
          "action": "Waiting for connectivity",
          "error": "\(error)"
        ])
        self._change(state: .pending, from: .connected)
        self._waitForConnectivityAndRestart()
        throw InternalError.onHold
      
      case .ECONNRESET:
        Logger.notice(.webSocket, "No connection", metadata: [
          "endpoint": "\(self.endpoint)",
          "error": "\(error)"
        ])
        let result = self._change(state: .pending, from: .connected)
        guard result.changed else { return nil }
        return .disconnected
        
      case .ECANCELED, .ECONNABORTED:
        Logger.notice(.webSocket, "No connection", metadata: [
          "endpoint": "\(self.endpoint)",
          "error": "\(error)"
        ])
        if self._intentionalDisconnect.value {
          self._process(closeCode: .protocolCode(.goingAway))
        }
        throw InternalError.disconnected
     
      default:
        return .error(error)
      }
      
    case .tls:
      Logger.critical(.webSocket, "TSL Error", metadata: [
        "error": "\(error)"
      ])
      self._change(state: .pending, from: nil)
      return .error(error)
    default:
      return .error(error)
    }
  }
  
  /// Handles changes in the connection state, updating the internal state and performing actions as necessary.
  /// - Parameter state: The new state of the connection.
  /// - Returns: An optional `Event` representing the state change, for broadcasting to consumers.
  private func _process(state: NWConnection.State) -> Event? {
    switch state {
    case .ready:
      self._change(state: .connected, from: nil)
      self._startPingPongTimer()
      return .connected
      
    case .waiting(let error):
      self._pendingRequests.write { pendings in
        pendings.forEach { $0.value.resume(throwing: WebSocket.ConnectionError.notReachable) }
        pendings.removeAll()
      }
      self._change(state: .pending, from: nil)
      self._stopPingPongTimer()
      self._waitForConnectivityAndRestart()
      return try? self._process(error: error)
      
    case .failed(let error):
      self._stopPingPongTimer()
      self._pendingRequests.write { pendings in
        pendings.forEach { $0.value.resume(throwing: WebSocket.ConnectionError.notReachable) }
        pendings.removeAll()
      }
      return try? self._process(error: error)
      
    case .setup:
      self._stopPingPongTimer()
      return nil
      
    case .preparing:
      self._stopPingPongTimer()
      return nil
      
    case .cancelled:
      self._stopPingPongTimer()
      self._pendingRequests.write { pendings in
        pendings.forEach { $0.value.resume(throwing: WebSocket.ConnectionError.notReachable) }
        pendings.removeAll()
      }
      let result = self._change(state: .disconnected, from: nil)
      guard result.changed, result.oldState == .connected else { return nil }
      return .disconnected
      
    @unknown default:
      return nil
    }
  }
  
  // MARK: - State handling
  
  /// Changes the internal state of the WebSocket connection.
  /// This method atomically updates the connection's state and logs the change.
  /// - Parameters:
  ///   - to: The new state to transition to.
  ///   - from: The current state from which to transition. If `nil`, the transition is not conditional on the current state.
  /// - Returns: A tuple containing a Boolean indicating whether the state changed and the old state before the change.
  @discardableResult
  private func _change(state to: State, from: State?) -> (changed: Bool, oldState: State) {
    let result = self._state.write {[weak self] state in
      if let from {
        // Changing states..
        guard from == state else { return (changed: false, oldState: state) }
      }
      let oldState = state
      guard state != to else { return (changed: false, oldState: state) }
      state = to
      Logger.trace(.webSocket, "Internal state changed", metadata: [
        "endpoint": "\(String(describing: self?.endpoint))",
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
  
  // MARK: - Connectivity
  
  /// Waits for connectivity to be established and then restarts the WebSocket connection.
  /// This method is called when the WebSocket connection encounters connectivity issues and needs to attempt a reconnection.
  private func _waitForConnectivityAndRestart() {
    self.connectivityTask.write {[weak self] task in
      guard task == nil else { return }
      task = Task {[weak self] in
        defer {
          self?.connectivityTask.write { task in
            task?.cancel()
            task = nil
          }
        }
        do {
          try await self?.connectivity.value.waitForConnectivity()
          Logger.notice(.webSocket, "Connectivity reached")
          // Wait a little bit extra
          try await Task.sleep(nanoseconds: 500_000_000)
          
          self?._restartConnection()
          
          if let stream = self?.listener.value {
            // Restart holded stream continuation
            self?._listen(stream)
          }
        } catch {
          Logger.notice(.webSocket, "Connectivity task cancelled")
        }
      }
    }
  }
  
  // MARK: - Disconnect
  
  /// Disconnects the WebSocket connection if there are no active consumers.
  /// This method ensures the connection is not unnecessarily kept alive when there are no interested parties.
  /// - Returns: A Boolean indicating whether the disconnection was initiated.
  @discardableResult
  private func _disconnectIfNeeded() -> Bool {
    guard self.consumers.value.isEmpty else { return false }
    Logger.trace(.webSocket, "Termination", metadata: [
      "endpoint": "\(self.endpoint)",
      "reason": "no consumers"
    ])
    let changed: Bool = self._intentionalDisconnect.write { value in
      guard !value else { return false }
      value = true
      return true
    }
    guard changed else { return true }
    self._intentionalDisconnect.value = true
    self._process(closeCode: .protocolCode(.goingAway))
    return true
  }
  
  /// Processes the closing of the WebSocket connection with a specific close code.
  /// This method properly closes the WebSocket connection using the provided close code, ensuring protocol compliance.
  /// - Parameter closeCode: The close code indicating the reason for disconnection.
  private func _process(closeCode: NWProtocolWebSocket.CloseCode) {
    Logger.trace(.webSocket, "Process close", metadata: [
      "endpoint": "\(self.endpoint)",
      "code": "\(closeCode)"
    ])
    
    self.disconnectTask.write {[weak self] task in
      guard task == nil else { return }
      task = Task {[weak self] in
        guard let self else { return }
        do {
          try Task.checkCancellation()
          await self._disconnect(closeCode: closeCode)
        } catch {
          Logger.trace(.webSocket, "Process close cancelled", metadata: [
            "endpoint": "\(self.endpoint)",
            "code": "\(closeCode)"
          ])
        }
      }
    }
  }
  
  /// Performs the actual disconnection of the WebSocket connection using a specific close code.
  /// This asynchronous method sends a close frame to the server and then shuts down the connection.
  /// - Parameter closeCode: The `NWProtocolWebSocket.CloseCode` indicating the reason for disconnection.
  private func _disconnect(closeCode: NWProtocolWebSocket.CloseCode) async {
    Logger.trace(.webSocket, "Internal disconnect triggered", metadata: [
      "endpoint": "\(self.endpoint)"
    ])
    do {
      let meta = NWProtocolWebSocket.Metadata(opcode: .close)
      meta.closeCode = closeCode
      try await send(data: nil, opcode: .close, meta: meta)
      Logger.trace(.webSocket, "Close message sent", metadata: [
        "endpoint": "\(self.endpoint)",
        "code": "\(closeCode)"
      ])
    } catch {
      Logger.notice(.webSocket, "Close message failed", metadata: [
        "endpoint": "\(self.endpoint)",
        "error": "\(error)"
      ])
    }
    self.connectivityTask.write { task in
      task?.cancel()
      task = nil
    }
    
    self.listener.write { listener in
      listener?.finish()
      listener = nil
    }
    self.connection.write { connection in
      connection?.cancel()
      connection = nil
    }
  }
  
  // MARK: - Ping Pong
  
  /// Starts a timer to send ping messages at regular intervals, according to the configuration.
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
  
  /// Stops the ping message timer when it is no longer needed, such as upon disconnection.
  private func _stopPingPongTimer() {
    self.pingPongTimer.write { timer in
      timer?.invalidate()
      timer = nil
    }
  }
}
