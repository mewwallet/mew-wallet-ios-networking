import Foundation
import Starscream
import Combine
import mew_wallet_ios_extensions
import mew_wallet_ios_logger
import os

public final class SocketNetworkClient: NetworkClient {
  private let url: URL
  private let headers: Headers
  
  public var dataBuilder: SocketDataBuilder!
  private var requestsHandler: SocketRequestsHandler = .init()
  
  private let _messagePublisher: PassthroughSubject<(ValueWrapper, Data), Never> = .init()
  
  private lazy var socket: WebSocket = {
    let request = self.dataBuilder.buildConnectionRequest(
      url: self.url,
      headers: self.headers
    )
    let socket = WebSocket(request: request)
    socket.delegate = self
    DispatchQueue.main.async {
      socket.connect()
    }
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
              // TODO: Make pretty
              // subscription
              try? await self.send(request: val.0, publisher: val.2)
            } else {
              
            }
          }
          let dataPool = await self.requestsHandler.drainDataPool()
          dataPool.forEach { value in
            Task {
              await self.send(id: value.0, data: value.1)
            }
          }
        } else {
          await self.requestsHandler.send(error: SocketClientError.noConnection, includingSubscription: true)
        }
      }
    }
  }
  
  public init(url: URL, headers: Headers) {
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
          let (id, payload) = try self.dataBuilder.unwrap(request: request)
          if request.useCommonMessagePublisher {
            continuation.resume(returning: _messagePublisher.eraseToAnyPublisher())
            // TODO: make async
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
              Task {
                await self.send(id: id, data: payload)
              }
            }
          } else if request.subscription {
            let passthrough = await self.requestsHandler.publisher(for: id)?.publisher ?? passthrough
            let publisher = SocketClientPublisher(publisher: passthrough)
            try await self.send(request: request, publisher: publisher)
            continuation.resume(returning: passthrough.eraseToAnyPublisher())
          } else {
            // TODO: replace completion with continuation
            try await send(
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
      guard self.isConnected ?? false else {
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
      guard self.isConnected ?? false else {
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
    guard self.isConnected ?? false else {
      await self.requestsHandler.addToPool(data: (id, data))
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
            if await requestsHandler.shouldUseCommonPublisher(for: id) {
              _messagePublisher.send((id, response))
            } else {
              await self.requestsHandler.send(data: response, subscriptionId: subscriptionId, to: id)
            }
          } else if let subscriptionId = subscriptionId {
            if await requestsHandler.shouldUseCommonPublisher(for: subscriptionId) {
              _messagePublisher.send((subscriptionId, response))
            } else {
              await self.requestsHandler.send(data: response, to: subscriptionId)
            }
          }
        } catch {
          Logger.debug(.socketNetworkClient, error)
        }
        
      case .cancelled:
        Logger.debug(.socketNetworkClient, ">>> cancelled")
        self.reconnect()
        
      case let .error(error):
        Logger.debug(.socketNetworkClient, ">>> error: \(error?.localizedDescription ?? "<empty>")")
        self.reconnect()
        
      case .disconnected:
        Logger.debug(.socketNetworkClient, ">>> disconnected")
        self.reconnect()
        
      case .connected:
        Logger.debug(.socketNetworkClient, ">>> connected")
        self.isConnected = true
      case .ping:
        socket.write(pong: Data())
        
      case .viabilityChanged(let viability):
        if !viability {
          self.reconnect()
        }
      default:
        Logger.debug(.socketNetworkClient, String(describing: event))
      }
    }
  }
}
