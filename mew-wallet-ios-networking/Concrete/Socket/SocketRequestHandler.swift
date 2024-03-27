import Foundation
import mew_wallet_ios_extensions
import mew_wallet_ios_logger

// swiftlint:disable large_tuple
typealias SocketClientResult = Result<NetworkResponse, Error>

final actor SocketRequestsHandler: Sendable {
  private var dataPool: [(IDWrapper, Data)] = []
  private var pool: [(any NetworkRequest, Bool, SocketClientPublisher?)] = []
  private var publishers: [IDWrapper: (SocketClientPublisher, Bool)] = [:]
  private var commonPublishers: [IDWrapper: SocketClientPublisher] = [:]
  
  var subscriptionId: IDWrapper? {
    return self.publishers.first(where: { $0.value.1 })?.key
  }
  
  func publisher(for requestId: IDWrapper, publisherId: IDWrapper?) -> SocketClientPublisher? {
    if let publisherId = publisherId, let publisher = commonPublishers[publisherId] {
      return publisher
    }
    return publishers[requestId]?.0
  }
  
  func add(publisher: SocketClientPublisher, subscription: Bool, for id: IDWrapper) {
    self.publishers[id] = (publisher, subscription)
  }
  
  @discardableResult
  func registerCommonPublisher(publisher: SocketClientPublisher, with id: IDWrapper?) -> Bool {
    guard
      let id = id,
      commonPublishers[id] == nil
    else {
      return false
    }
    
    commonPublishers[id] = publisher
    return true
  }
  
  func shouldUseCommonPublisher(for id: IDWrapper) -> Bool {
    return commonPublishers[id] != nil
  }
  
  func send(data: Data, subscriptionId: IDWrapper?, to id: IDWrapper) {
    guard let (publisher, subscription) = self.publishers[id] else {
      Logger.error(.socketNetworkClient, "No publisher for id: \(id). Publishers: \(self.publishers)")
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
  
  func send(data: Data, to id: IDWrapper) {
    guard let (publisher, subscription) = self.publishers[id] else {
      Logger.error(.socketNetworkClient, "No publisher for id: \(id). Publishers: \(self.publishers)")
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
      $0.2?.send(signal: .failure(error))
    }
    self.pool.removeAll()
  }
  
  func sendReconnectedEvent() {
    var publishers = Set<SocketClientPublisher>()
    
    // only for subscriptions
    self.publishers
      .lazy
      .filter { $0.1.1 }
      .forEach {
        publishers.insert($0.value.0)
      }
    
    self.commonPublishers.lazy.forEach {
      publishers.insert($0.value)
    }
    
    publishers.forEach {
      $0.send(signal: .failure(SocketClientError.connected))
    }
  }
  
  // MARK: - Pool of requests
  
  func addToPool(request: (any NetworkRequest, Bool, SocketClientPublisher?)) {
    self.pool.append(request)
  }
  
  func addToPool(data: (IDWrapper, Data)) {
    self.dataPool.append(data)
  }
  
  func drainPool() -> [(any NetworkRequest, Bool, SocketClientPublisher?)] {
    let pool = self.pool
    self.pool.removeAll()
    return pool
  }
  
  func drainDataPool() -> [(IDWrapper, Data)] {
    let pool = self.dataPool
    self.dataPool.removeAll()
    return pool
  }
  
  func reset() {
    self.dataPool.removeAll()
    self.pool.removeAll()
    self.commonPublishers.lazy.forEach {
      $0.value.send(signal: .failure(SocketClientError.noConnection))
    }
    self.commonPublishers.removeAll()
    self.publishers.lazy.forEach {
      $0.value.0.send(signal: .failure(SocketClientError.noConnection))
    }
    self.publishers.removeAll()
  }
}
// swiftlint:enable large_tuple
