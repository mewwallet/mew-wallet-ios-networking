import Foundation
import Starscream
import Combine
import mew_wallet_ios_extensions
import mew_wallet_ios_logger
import os

public final class SocketNetworkClient: NetworkClient {
  enum ConnectionState {
    case disconnected
    case reconnecting
    case connecting
    case connected
  }
  private let url: URL
  private let headers: Headers
  
  public var dataBuilder: SocketDataBuilder!
  private var requestsHandler: SocketRequestsHandler = .init()
    
  private lazy var socket: WebSocket = {
    return newClient()
  }()
  
  private var connectionState: ConnectionState = .disconnected {
    didSet {
      switch self.connectionState {
      case .disconnected:
        self.stopPing()
        self.stopReconnectionTimer()
        
        Task {[weak self] in
          await self?.requestsHandler.send(error: SocketClientError.noConnection, includingSubscription: true)
        }
      case .reconnecting:
        self.stopPing()
        self.startReconnectionTimer()
        
        Task {[weak self] in
          await self?.requestsHandler.send(error: SocketClientError.noConnection, includingSubscription: true)
        }
      case .connecting:
        self.stopPing()
        self.stopReconnectionTimer()
        
        if oldValue == .connected {
          Task {[weak self] in
            await self?.requestsHandler.send(error: SocketClientError.noConnection, includingSubscription: true)
          }
        }
      case .connected:
        self.startPing()
        self.stopReconnectionTimer()
        
        Task {[weak self] in
          guard let self else { return }
          let pool = await self.requestsHandler.drainPool()
          for val in pool {
            if val.1 {
              // TODO: Make pretty
              // subscription
              try? await self.send(request: val.0, publisher: val.2)
            } else if let continuation = val.2.continuation {
              try? await self.send(request: val.0, continuation: continuation)
            }
          }
          let dataPool = await self.requestsHandler.drainDataPool()
          dataPool.forEach { value in
            Task {
              await self.send(id: value.0, data: value.1)
            }
          }
          if oldValue != .connected {
            await self.requestsHandler.sendReconnectedEvent()
          }
        }
      }
    }
  }
  
  public init(url: URL, headers: Headers) {
    self.url = url
    self.headers = headers
  }
  
  deinit {
    socket.disconnect()
    Task {[handler = self.requestsHandler] in
      await handler.send(error: SocketClientError.noConnection, includingSubscription: true)
    }
  }
  
  // MARK: - Client Management
  
  private func newClient() -> WebSocket {
    let request = self.dataBuilder.buildConnectionRequest(
      url: self.url,
      headers: self.headers
    )
    let socket = WebSocket(request: request)
    socket.delegate = self
    socket.respondToPingWithPong = true
    DispatchQueue.main.async {
      self.connect()
    }
    return socket
  }
  
  // MARK: - Reconnection
  
  private var reconnectTask: Task<Void, Never>?
  private let reconnectLock = NSLock()
  
  func startReconnectionTimer() {
    reconnectLock.withLock {
      reconnectTask = Task(priority: .utility) {[weak self] in
        do {
          try await Task.sleep(nanoseconds: 5_000_000_000)
          await self?.reconnect(force: true)
        } catch {
        }
      }
    }
  }
  
  func stopReconnectionTimer() {
    reconnectLock.withLock {
      reconnectTask?.cancel()
      reconnectTask = nil
    }
  }
  
  // MARK: - Ping/Pong
  
  private var pingTask: Task<Void, Never>?
  private let pingLock = NSLock()
  private var pingPongCount: Int = 0
  
  func startPing() {
    pingLock.withLock {
      guard pingTask == nil else { return }
      self.pingTask = Task(priority: .utility) {[weak self] in
        do {
          while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            Task { @MainActor [weak self] in
              self?.increasePing()
              self?.socket.write(ping: Data())
            }
          }
        } catch {
        }
      }
    }
  }
  
  func stopPing() {
    pingLock.withLock {
      self.pingTask?.cancel()
      self.pingTask = nil
    }
  }
  
  func increasePing() {
    pingLock.withLock {
      self.pingPongCount += 1
      guard pingPongCount >= 3 else { return }
      Task {[weak self] in
        await self?.reconnect(force: true)
      }
    }
  }
  
  func decreasePing() {
    pingLock.withLock {
      self.pingPongCount -= 1
    }
  }
  
  // MARK: - Send
  
  public func send(request: NetworkRequest) async throws -> Any {
    guard let request = request as? SocketRequest else {
      throw SocketClientError.badFormat
    }
    
    Logger.debug(.socketNetworkClient,
      """
      
      ==========New socket task:==========
      Subscription: \(request.subscription)
      PublisherId: \(request.publisherId ?? "<none>")
      Request: \(String(describing: request.request))
      =====================================
      """
    )
    
    return try await withCheckedThrowingContinuation { continuation in
      Task {[weak self] in
        guard let self else { return continuation.resume(throwing: NetworkTask.Error.aborted) }
        var passthrough = PassthroughSubject<Result<NetworkResponse, Error>, Never>()
        do {
          let (id, _) = try self.dataBuilder.unwrap(request: request)

          if request.subscription {
            let publisherId = request.publisherId.map { ValueWrapper.stringValue($0) }
            await self.requestsHandler.registerCommonPublisher(for: publisherId)

            if let storedPassthrough = await self.requestsHandler.publisher(for: id, publisherId: publisherId)?.publisher {
              passthrough = storedPassthrough
            }
            let publisher = SocketClientPublisher(publisher: passthrough)
            try await self.send(request: request, publisher: publisher)
            continuation.resume(returning: passthrough.eraseToAnyPublisher())
          } else {
            try await self.send(
              request: request,
              continuation: continuation
            )
          }
        } catch {
          if request.subscription {
            continuation.resume(returning: passthrough.eraseToAnyPublisher())
          } else {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }
}

extension SocketNetworkClient {
  private func send(
    request: NetworkRequest,
    publisher: SocketClientPublisher
  ) async throws {
    Logger.debug(.socketNetworkClient,
          """
          
          =========New subscription websocket task:=========
          =====================================
          """)
    _ = socket // initialize socket
    
    do {
      guard self.connectionState == .connected else {
        await self.requestsHandler.addToPool(request: (request, true, publisher))
        return
      }
      let (id, payload) = try self.dataBuilder.unwrap(request: request)
      await self.requestsHandler.add(publisher: publisher, subscription: true, for: id)
      
      self.socket.write(data: payload)
    } catch {
      Logger.debug(.socketNetworkClient,
        """
        ======New websocket task error:======
         Error:
          \(error.localizedDescription)
        =====================================
        \u{2028}
        """)
      throw error
    }
  }
  
  private func send(
    request: NetworkRequest,
    continuation: CheckedContinuation<Any, Error>
  ) async throws {
    Logger.debug(.socketNetworkClient,
      """
      =========New sync websocket task:=========
      =====================================
      """
    )
    
    _ = socket // initialize socket
    
    do {
      let publisher = SocketClientPublisher(continuation: continuation)
      if self.connectionState == .connecting {
        await self.requestsHandler.addToPool(request: (request, false, publisher))
        return
      }

      guard self.connectionState == .connected else {
        throw SocketClientError.noConnection
      }
      let (id, payload) = try self.dataBuilder.unwrap(request: request)
      await self.requestsHandler.add(publisher: publisher, subscription: false, for: id)
      
      self.socket.write(data: payload)
    } catch {
      Logger.debug(.socketNetworkClient,
        """
        ======New websocket task error:======
         Error:
          \(error.localizedDescription)
        =====================================
        \u{2028}
        """)
      throw error
    }
  }
  
  private func send(id: ValueWrapper, data: Data) async {
    await requestsHandler.registerCommonPublisher(for: id)
    guard self.connectionState == .connected else {
      await self.requestsHandler.addToPool(data: (id, data))
      return
    }
    self.socket.write(data: data)
  }
  
  @MainActor func connect() {
    guard connectionState == .disconnected else { return }
    connectionState = .connecting
    Logger.debug(.socketNetworkClient, ">> Connect to: \(String(describing: socket.request.url))")
    socket.connect()
  }
  
  @MainActor func disconnect() {
    guard connectionState != .disconnected else { return }
    connectionState = .disconnected
    Logger.debug(.socketNetworkClient, ">> Disconnect from: \(String(describing: socket.request.url))")
    socket.disconnect()
  }
  
  @MainActor func reconnect(force: Bool) {
    guard force || connectionState != .reconnecting else { return }
    Logger.debug(.socketNetworkClient, ">> Reconnect to: \(String(describing: socket.request.url))")
    connectionState = .reconnecting
    socket.disconnect()
    self.socket = self.newClient()
    socket.connect()
  }
}

extension SocketNetworkClient: WebSocketDelegate {
  public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
    Task {
      switch event {
      case .text(let text):
        Logger.debug(.socketNetworkClient,
          """
          =======New websocket message:========
           Message:
            \(text)
          =====================================
          \u{2028}
          """
        )
        do {
          let (id, subscriptionId, response) = try self.dataBuilder.unwrap(response: text)
          if let id = id {
            await self.requestsHandler.send(data: response, subscriptionId: subscriptionId, to: id)
          } else if let subscriptionId = subscriptionId {
            await self.requestsHandler.send(data: response, to: subscriptionId)
          }
        } catch {
          Logger.debug(.socketNetworkClient, error)
        }
        
      case .cancelled:
        Logger.debug(.socketNetworkClient, ">>> cancelled")
        await self.reconnect(force: false)
        
      case let .error(error):
        Logger.debug(.socketNetworkClient, ">>> error: \(error?.localizedDescription ?? "<empty>")")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await self.reconnect(force: false)
        
      case .disconnected:
        Logger.debug(.socketNetworkClient, ">>> disconnected")
        await self.reconnect(force: false)
        
      case .connected:
        Logger.debug(.socketNetworkClient, ">>> connected")
        self.connectionState = .connected
        
      case .pong:
        self.decreasePing()
        
      case .viabilityChanged(let viability):
        Logger.debug(.socketNetworkClient, ">>> viabilityChanged(\(viability))")
        if !viability {
          await self.reconnect(force: false)
        }
      default:
        Logger.debug(.socketNetworkClient, String(describing: event))
      }
    }
  }
}
