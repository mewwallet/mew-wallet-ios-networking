//
//  File.swift
//  
//
//  Created by Nail Galiaskarov on 10/1/22.
//

import Foundation
import mew_wallet_ios_extensions

struct SocketClientPublisher: Sendable {
  private let _publisher = ThreadSafe<BroadcastAsyncStream<Result<NetworkResponse, Error>>?>(nil)
  var publisher: BroadcastAsyncStream<Result<NetworkResponse, Error>>? {
    return _publisher.value
  }
  let continuation: CheckedContinuation<any Sendable, Error>?
  
  init(
    publisher: BroadcastAsyncStream<Result<NetworkResponse, Error>>? = nil,
    continuation: CheckedContinuation<any Sendable, Error>? = nil
  ) {
    self._publisher.value = publisher
    self.continuation = continuation
  }
  
  func send(signal: Result<NetworkResponse, Error>) {
    _publisher.value?.yield(signal)
    do {
      let result = try signal.get()
      continuation?.resume(returning: result)
    } catch {
      continuation?.resume(throwing: error)
    }
  }
  
  func complete(signal: Result<NetworkResponse, Error>) {
    _publisher.value?.finish()
    do {
      let result = try signal.get()
      continuation?.resume(returning: result)
    } catch {
      continuation?.resume(throwing: error)
    }
  }
}

extension SocketClientPublisher: Equatable {
  static func == (lhs: SocketClientPublisher, rhs: SocketClientPublisher) -> Bool {
    return lhs.publisher?.id == rhs.publisher?.id
  }
}

extension SocketClientPublisher: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(publisher)
  }
}
