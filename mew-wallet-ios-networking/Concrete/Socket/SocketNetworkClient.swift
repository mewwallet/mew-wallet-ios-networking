import Foundation
import mew_wallet_ios_extensions
import mew_wallet_ios_logger
import mew_wallet_ios_networking_websocket
import os

public final class SocketNetworkClient: NetworkClient {
  enum ConnectionState {
    case disconnected
    case connected
  }
  
  private let url: URL
  private let headers: Headers
  
  private let dataBuilder: SocketDataBuilder
  private let requestsHandler: SocketRequestsHandler = .init()
    
  private let socket: WebSocket
  
  private let _listenerTask = ThreadSafe<Task<Void, Never>?>(nil)
  
  public init(url: URL, headers: Headers, dataBuilder :SocketDataBuilder) {
    self.url = url
    self.headers = headers
    self.dataBuilder = dataBuilder
    do {
      self.socket = try WebSocket(url: self.url, headers: self.headers.array)
      self.connect()
    } catch {
      fatalError()
    }
  }
  
  deinit {
    socket.disconnect()
    _listenerTask.value?.cancel()
    Task {[handler = self.requestsHandler] in
      await handler.send(error: SocketClientError.noConnection, includingSubscription: true)
    }
  }
}

// MARK: - SocketNetworkClient + Send

extension SocketNetworkClient {
  public func send(request: NetworkRequest) async throws -> any Sendable {
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

    return try await withCheckedThrowingContinuation {[weak self] continuation in
      guard let self else { return }
      Task { [weak self] in
        guard let self else { return continuation.resume(throwing: NetworkTask.Error.aborted) }
        var passthrough = BroadcastAsyncStream<Result<NetworkResponse, Error>>()
        do {
          let (id, _) = try self.dataBuilder.unwrap(request: request)

          if request.subscription {
            let publisherId = request.publisherId.map { IDWrapper.left($0) }

            if let storedPassthrough = await self.requestsHandler.publisher(for: id, publisherId: publisherId)?.publisher {
              passthrough = storedPassthrough
            }
            let publisher = SocketClientPublisher(publisher: passthrough)
            await self.requestsHandler.registerCommonPublisher(publisher: publisher, with: publisherId) // (for: publisherId)
            try await self.send(request: request, publisher: publisher)
            continuation.resume(returning: passthrough)
          } else {
            try await self.send(request: request, continuation: continuation)
          }
        } catch {
          if request.subscription {
            continuation.resume(returning: passthrough)
          } else {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  }

  @discardableResult public func sendAndForget(request: NetworkRequest) async throws -> (any Sendable)? {
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
    try await self._send(
      request: request
    )
    return nil
  }

  private func send(
    request: NetworkRequest,
    publisher: SocketClientPublisher
  ) async throws {
    Logger.debug(.socketNetworkClient,
      """

      =========New subscription websocket task:=========
      \(String(describing: request.request))
      ==================================================
      \u{2028}
      """)
    _ = socket // initialize socket

    do {
      guard self.socket.state == .connected else {
        await self.requestsHandler.addToPool(request: (request, true, publisher))
        return
      }
      
      let (id, payload) = try self.dataBuilder.unwrap(request: request)
      await self.requestsHandler.add(publisher: publisher, subscription: true, for: id)

      try await self.socket.send(payload)
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
    continuation: CheckedContinuation<any Sendable, Error>
  ) async throws {
    Logger.debug(.socketNetworkClient,
      """
      =========New sync websocket task:=========
       Request:
        \(request)
      ==========================================
      \u{2028}
      """
    )

    _ = socket // initialize socket

    do {
      let publisher = SocketClientPublisher(continuation: continuation)
      if self.socket.state == .pending {
        await self.requestsHandler.addToPool(request: (request, false, publisher))
        return
      }

      guard self.socket.state == .connected else {
        throw SocketClientError.noConnection
      }
      let (id, payload) = try self.dataBuilder.unwrap(request: request)
      await self.requestsHandler.add(publisher: publisher, subscription: false, for: id)

      try await self.socket.send(payload)
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

  private func send(id: IDWrapper, data: Data) async {
    do {
      guard self.socket.state == .connected else {
        await self.requestsHandler.addToPool(data: (id, data))
        return
      }
      try await self.socket.send(data)
    } catch {
      Logger.debug(.socketNetworkClient,
        """
        ======New websocket task error:======
         Error:
          \(error.localizedDescription)
        =====================================
        \u{2028}
        """)
    }
  }

  private func _send(
    request: NetworkRequest
  ) async throws {
    Logger.debug(.socketNetworkClient,
      """
      =========New sync websocket task:=========
       Request:
        \(request)
      ==========================================
      \u{2028}
      """
    )

    _ = socket // initialize socket

    do {
      guard self.socket.state != .pending else {
        await self.requestsHandler.addToPool(request: (request, false, nil))
        return
      }

      guard self.socket.state == .connected else {
        throw SocketClientError.noConnection
      }
      let (_, payload) = try self.dataBuilder.unwrap(request: request)

      try await self.socket.send(payload)
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
}


extension SocketNetworkClient {
  func connect() {
    guard self.socket.state == .disconnected else { return }
    Task(priority: .utility, operation: {[weak self] in
      guard let self else { return }
      for await event in self.socket.connect() {
        Logger.debug(.socketNetworkClient, ">> Event: \(event)")
        switch event {
        case .connected:
          Logger.debug(.socketNetworkClient, ">>> connected")
          self.handleConnectionState(.connected)
          
        case .disconnected:
          Logger.debug(.socketNetworkClient, ">>> disconnected")
          self.handleConnectionState(.disconnected)
          
        case .viabilityDidChange(let isViable):
          Logger.debug(.socketNetworkClient, ">>> viabilityChanged(\(isViable))")

        case .ping:
          break
          
        case .pong:
          break
          
        case .text(let text):
          guard let text else { return }
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
        case .binary(let data):
          guard let data,
                let text = String(data: data, encoding: .utf8) else { return }
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
          
        case .error(let error):
          Logger.debug(.socketNetworkClient, ">>> error: \(error.localizedDescription)")
          
        case .connectionError(let error):
          Logger.debug(.socketNetworkClient, ">>> error: \(error.localizedDescription)")
        }
      }
    })
  }
  
  private func handleConnectionState(_ state: ConnectionState) {
    switch state {
    case .disconnected:
      Task { [weak self] in
        await self?.requestsHandler.send(error: SocketClientError.noConnection, includingSubscription: true)
      }
    case .connected:
      Task {[weak self] in
        guard let self else { return }
        let pool = await self.requestsHandler.drainPool()
        for val in pool {
          if val.1 {
            // TODO: Make pretty
            // subscription
            if let publisher = val.2 {
              try? await self.send(request: val.0, publisher: publisher)
            } else {
              _ = try? await self.sendAndForget(request: val.0)
            }
          } else if let continuation = val.2?.continuation {
            try? await self.send(request: val.0, continuation: continuation)
          } else {
            _ = try? await self.sendAndForget(request: val.0)
          }
        }
        let dataPool = await self.requestsHandler.drainDataPool()
        dataPool.forEach { value in
          Task {[weak self] in
            await self?.send(id: value.0, data: value.1)
          }
        }
        await self.requestsHandler.sendReconnectedEvent()
      }
    }
  }
  
  func disconnect() {
    guard self.socket.state != .disconnected else { return }
    socket.disconnect()
    _listenerTask.value?.cancel()
    Task {[handler = self.requestsHandler] in
      await handler.send(error: SocketClientError.noConnection, includingSubscription: true)
    }
  }
}
