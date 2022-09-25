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
            try? await self.send(request: val.0, subscription: val.1, publisher: val.2)
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
        do {
          // TODO: use this only for subscription
          let (id, payload) = try self.dataBuilder.unwrap(request: request)
          let passthrough = PassthroughSubject<Result<NetworkResponse, Error>, Never>()
          try await send(request: request, subscription: false, publisher: passthrough)
          continuation.resume(returning: passthrough.eraseToAnyPublisher())
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}

extension SocketNetworkClient {
  private func send(request: NetworkRequest, subscription: Bool, publisher: SocketClientPublisher) async throws {
      debugPrint(
      """
      =========New websocket task:=========
      =====================================
      """
      )
    
      _ = socket // initialize socket
      
      do {
        guard self.isConnected ?? false else {
          if !subscription {
            guard self.isConnected != nil else {
              throw SocketClientError.noConnection
            }
          }
          await self.requestsHandler.addToPool(request: (request, subscription, publisher))
          return
        }
        let (id, payload) = try self.dataBuilder.unwrap(request: request)
        await self.requestsHandler.add(publisher: publisher, subscription: subscription, for: id)
        
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
