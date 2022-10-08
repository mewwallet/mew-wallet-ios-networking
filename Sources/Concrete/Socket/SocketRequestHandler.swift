import Foundation
import mew_wallet_ios_extensions
import Combine

// swiftlint:disable large_tuple
typealias SocketClientResult = Result<NetworkResponse, Error>

final actor SocketRequestsHandler {
  private var dataPool: [Data] = []
  private var pool: [(NetworkRequest, Bool, SocketClientPublisher)] = []
  private var publishers: [ValueWrapper: (SocketClientPublisher, Bool)] = [:]
  
  var subscriptionId: ValueWrapper? {
    return self.publishers.first(where: { $0.value.1 })?.key
  }
  
  func publisher(for id: ValueWrapper) -> SocketClientPublisher? {
    return publishers[id]?.0
  }
  
  func add(publisher: SocketClientPublisher, subscription: Bool, for id: ValueWrapper) {
    self.publishers[id] = (publisher, subscription)
  }
  
  func send(data: Data, subscriptionId: ValueWrapper?, to id: ValueWrapper) {
    guard let (publisher, subscription) = self.publishers[id] else {
      return
    }
    if subscription {
      self.publishers.removeValue(forKey: id)
      if let subscriptionId = subscriptionId, subscription {
        self.publishers[subscriptionId] = (publisher, true)
      }
    } else {
      publisher.send(signal: .success(RESTResponse(nil, data: data, statusCode: 200)))
    }
  }
  
  func send(data: Data, to id: ValueWrapper) {
    guard let (publisher, _) = self.publishers[id] else {
      return
    }
    publisher.send(signal: .success(RESTResponse(nil, data: data, statusCode: 200)))
  }
  
  func send(error: Error, includingSubscription: Bool) {
    self.publishers
      .lazy
      .filter { !$0.1.1 || includingSubscription}
      .forEach {
        $0.value.0.send(signal: .failure(error))
      }
    self.publishers.removeAll()
    self.pool.forEach {
      $0.2.send(signal: .failure(error))
    }
    self.pool.removeAll()
  }
  
  // MARK: - Pool of requests
  
  func addToPool(request: (NetworkRequest, Bool, SocketClientPublisher)) {
    self.pool.append(request)
  }
  
  func addToPool(data: Data) {
    self.dataPool.append(data)
  }
  
  func drainPool() -> [(NetworkRequest, Bool, SocketClientPublisher)] {
    let pool = self.pool
    self.pool.removeAll()
    return pool
  }
  
  func drainDataPool() -> [Data] {
    let pool = self.dataPool
    self.dataPool.removeAll()
    return pool
  }
}
// swiftlint:enable large_tuple
