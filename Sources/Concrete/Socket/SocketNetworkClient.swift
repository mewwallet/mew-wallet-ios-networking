import Foundation
import Starscream
import Combine

public final class SocketNetworkClient: NetworkClient {
  private let url: URL
  private let headers: [String: String]
  
  public var dataBuilder: SocketDataBuilder!
  private var requestsHandler: SocketRequestsHandler = .init()

  private lazy var socket: WebSocket = {
    let request = self.dataBuilder.buildConnectionRequest(
      url: self.url,
      headers: self.headers
    )
    let socket = WebSocket(request: request)
    socket.delegate = self
    socket.connect()
    return socket
  }()
  
  private var isConnected: Bool? {
    didSet {
      guard let isConnected = isConnected else {
        return
      }

      Task {
        if isConnected {
          let pool = await self.requestsHandler.drainPool()
          for val in pool {
            if val.1 {
              // subscription
              try? await self.send(request: val.0, publisher: val.2)
            } else {
              
            }
          }
          let dataPool = await self.requestsHandler.drainDataPool()
          dataPool.forEach {
            self.send(data: $0)
          }
        } else {
          await self.requestsHandler.send(error: SocketClientError.noConnection, includingSubscription: true)
        }
      }
    }
  }

  public init(
    url: URL,
    headers: [String: String]
  ) {
    self.url = url
    self.headers = headers
  }
  
  deinit {
    self.disconnect()
  }

  public func send(request: NetworkRequest) async throws -> Any {
    guard let request = request as? SocketRequest else {
      throw SocketClientError.badFormat
    }
    
    return try await withCheckedThrowingContinuation { continuation in
      Task {
        let passthrough = PassthroughSubject<Result<NetworkResponse, Error>, Never>()
        do {
          // TODO: use this only for subscription
          let (id, payload) = try self.dataBuilder.unwrap(request: request)
          if request.subscription {
            let publisher = SocketClientPublisher(publisher: passthrough)
            try await send(request: request, publisher: publisher)
            continuation.resume(returning: passthrough.eraseToAnyPublisher())
          } else {
            try await send(
              request: request,
              completionBlock: { result in
                switch result {
                case .success(let response):
                  continuation.resume(returning: response)
                case .failure(let error):
                  continuation.resume(throwing: error)
                }
              }
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
      debugPrint(
      """
      =========New subscription websocket task:=========
      =====================================
      """
      )
    
      _ = socket // initialize socket
      
      do {
        guard self.isConnected ?? false else {
          await self.requestsHandler.addToPool(request: (request, true, publisher))
          return
        }
        let (id, payload) = try self.dataBuilder.unwrap(request: request)
        await self.requestsHandler.add(publisher: publisher, subscription: true, for: id)
        
        self.socket.write(data: payload)
      } catch {
        debugPrint(
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
    completionBlock: @escaping (Result<NetworkResponse, Error>) -> Void
  ) async throws {
    debugPrint(
      """
      =========New sync websocket task:=========
      =====================================
      """
    )
    
    _ = socket // initialize socket
    
    do {
      let publisher = SocketClientPublisher(block: completionBlock)
      guard self.isConnected ?? false else {
        throw SocketClientError.noConnection
      }
      let (id, payload) = try self.dataBuilder.unwrap(request: request)
      await self.requestsHandler.add(publisher: publisher, subscription: false, for: id)
      
      self.socket.write(data: payload)
    } catch {
      debugPrint(
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
  
  private func send(data: Data) {
    guard self.isConnected ?? false else {
      Task {
        await self.requestsHandler.addToPool(data: data)
      }
      return
    }
    self.socket.write(data: data)
  }

  private func connect() {
    if Thread.isMainThread {
      socket.connect()
    } else {
      DispatchQueue.main.async {
        self.socket.connect()
      }
    }
  }
  
  private func disconnect() {
    if Thread.isMainThread {
      socket.disconnect()
      isConnected = false
    } else {
      DispatchQueue.main.async {
        self.socket.disconnect()
        self.isConnected = false
      }
    }
  }
  
  func reconnect() {
    if Thread.isMainThread {
      disconnect()
      connect()
    } else {
      DispatchQueue.main.async {
        self.disconnect()
        self.connect()
      }
    }
  }
}

extension SocketNetworkClient: WebSocketDelegate {
  public func didReceive(event: WebSocketEvent, client: WebSocket) {
    Task {
      switch event {
      case .text(let text):
        debugPrint(
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
          debugPrint(error.localizedDescription)
        }
        
      case .cancelled:
        debugPrint(">>> cancelled")
        self.reconnect()
        
      case let .error(error):
        debugPrint(">>> error: \(error?.localizedDescription ?? "<empty>")")
        self.reconnect()
        
      case .disconnected:
        debugPrint(">>> disconnected")
        self.reconnect()
        
      case .connected:
        debugPrint(">>> connected")
        self.isConnected = true
      case .ping:
        socket.write(pong: Data())
        
      case .viabilityChanged(let viability):
        if !viability {
          self.reconnect()
        }
      default:
        debugPrint(String(describing: event))
      }
    }
  }
}
