import Foundation
import Combine
import mew_wallet_ios_extensions

// swiftlint:disable large_tuple
typealias SocketClientResult = Result<NetworkResponse, Error>

final actor SocketRequestsHandler {
  private var dataPool: [(ValueWrapper, Data)] = []
  private var pool: [(NetworkRequest, Bool, SocketClientPublisher)] = []
  private var publishers: [ValueWrapper: (SocketClientPublisher, Bool)] = [:]
  private var commonPublishers: [ValueWrapper: Bool] = [:]
  
  var subscriptionId: ValueWrapper? {
    return self.publishers.first(where: { $0.value.1 })?.key
  }
  
  func publisher(for id: ValueWrapper) -> SocketClientPublisher? {
    return publishers[id]?.0
  }
  
  func add(publisher: SocketClientPublisher, subscription: Bool, for id: ValueWrapper) {
    self.publishers[id] = (publisher, subscription)
  }
  
  func registerCommonPublisher(for id: ValueWrapper) {
    commonPublishers[id] = true
  }
  
  func shouldUseCommonPublisher(for id: ValueWrapper) -> Bool {
    guard let use = commonPublishers[id] else {
      return false
    }
    return use
  }
  
  func send(data: Data, subscriptionId: ValueWrapper?, to id: ValueWrapper) {
    guard let (publisher, subscription) = self.publishers[id] else {
      return
    }
    self.publishers.removeValue(forKey: id)
    if subscription {
      if let subscriptionId = subscriptionId, subscription {
        self.publishers[subscriptionId] = (publisher, true)
      }
      publisher.send(signal: .success(RESTResponse(nil, data: data, statusCode: 200)))
    } else {
      publisher.send(signal: .success(RESTResponse(nil, data: data, statusCode: 200)))
    }
  }
  
  func send(data: Data, to id: ValueWrapper) {
    guard let (publisher, subscription) = self.publishers[id] else {
      return
    }
    publisher.send(signal: .success(RESTResponse(nil, data: data, statusCode: 200)))
    if (!subscription) {
      publishers.removeValue(forKey: id)
    }
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
  
  func addToPool(data: (ValueWrapper, Data)) {
    self.dataPool.append(data)
  }
  
  func drainPool() -> [(NetworkRequest, Bool, SocketClientPublisher)] {
    let pool = self.pool
    self.pool.removeAll()
    return pool
  }
  
  func drainDataPool() -> [(ValueWrapper, Data)] {
    let pool = self.dataPool
    self.dataPool.removeAll()
    return pool
  }
}
// swiftlint:enable large_tuple
