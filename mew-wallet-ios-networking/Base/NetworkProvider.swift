import Foundation
import mew_wallet_ios_logger
import mew_wallet_ios_extensions
import os

private enum Static {
  static let maxRetryAttempts = 3
}

public final class NetworkProvider<API: APINetworkPath>: GenericNetworkProvider, Sendable {
  public typealias APIPATH = API
  
  internal let uuid = UUID()
  private let _workTask = ThreadSafe<Task<Void, Never>?>(nil)
  private let _reconnectTask = ThreadSafe<Task<Void, Never>?>(nil)

  // MARK: - NetworkProvider

  public let configuration: Configuration
  private let _socketNetworkClient = ThreadSafe<SocketNetworkClient?>(nil)
  private var socketNetworkClient: SocketNetworkClient {
    get {
      self._socketNetworkClient.write {[weak self] client in
        guard client == nil else { return client! }
        guard let baseURL = self?.configuration.baseURL else { fatalError("No base url") }
        let socketNetworkClient = SocketNetworkClient(
          url: baseURL,
          headers: self?.configuration.headers ?? .empty,
          dataBuilder: SocketDataBuilderImpl()
        )
        client = socketNetworkClient
        return socketNetworkClient
      }
    }
  }

  private let _newHeadsSubscriptionId = ThreadSafe<String?>(nil)
  public var newHeadsSubscriptionId: String? { _newHeadsSubscriptionId.value }

  public init(with configuration: Configuration) {
    self.configuration = configuration
  }
  
  deinit {
    self._socketNetworkClient.write { client in
      client?.disconnect()
      client = nil
    }
    _workTask.value?.cancel()
    _reconnectTask.value?.cancel()
  }

  // MARK: - Public

  public func call<R>(_ api: APIPATH) throws -> APITask<R> {
    guard api.isSocket else {
      return try api.task(configuration, provider: self)
    }
    do {
      return try api.taskDrySubscriptionResult(from: newHeadsSubscriptionId, provider: self)
    } catch {
      return try api.task(configuration, socketClient: socketNetworkClient, provider: self)
    }
  }

  // MARK: - GenericNetworkProvider

  public func postProcess<R>(task: APITask<R>, result: R) {
    guard let publisher = result as? BroadcastAsyncStream<Result<(any Sendable)?, Error>> else { return }
    
    _workTask.write {[weak self, weak task] workTask in
      guard workTask == nil else { return }
      
      workTask = Task {[weak self, weak task] in
        for await value in publisher {
          do {
            try Task.checkCancellation()
            let result = try value.get()
            guard self?._newHeadsSubscriptionId.value == nil else { continue }
            guard let id = try task?.path.taskSubscriptionId(result: result) else { continue }
            self?._newHeadsSubscriptionId.value = id
          } catch SocketClientError.noConnection {
            self?._newHeadsSubscriptionId.value = nil
          } catch SocketClientError.connected {
            if let task, self?._newHeadsSubscriptionId.value != nil {
              self?.reconnectSubscription(task: task)
            }
          } catch is CancellationError {
            return
          } catch {
            continue
          }
        }
      }
    }
  }
  
  private func reconnectSubscription<R: Sendable>(task: APITask<R>?, retryAttempt: Int = 0) {
    guard retryAttempt < Static.maxRetryAttempts else { return }
    
    _reconnectTask.write {[weak self, weak task] workTask in
      workTask?.cancel()
      workTask = Task { [weak self, weak task] in
        guard let self else { return }
        
        do {
          guard let task: APITask<R> = try task?.path.task(configuration, socketClient: self.socketNetworkClient, provider: self) else { return }
          _ = try await task.execute()
        } catch {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          self.reconnectSubscription(task: task, retryAttempt: retryAttempt + 1)
        }
      }
    }
  }
}
