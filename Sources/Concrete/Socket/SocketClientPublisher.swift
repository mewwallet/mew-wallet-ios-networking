//
//  File.swift
//  
//
//  Created by Nail Galiaskarov on 10/1/22.
//

import Foundation
import Combine

struct SocketClientPublisher {
  let publisher: PassthroughSubject<Result<NetworkResponse, Error>, Never>?
  let continuation: CheckedContinuation<Any, Error>?
  
  init(
    publisher: PassthroughSubject<Result<NetworkResponse, Error>, Never>? = nil,
    continuation: CheckedContinuation<Any, Error>? = nil
  ) {
    self.publisher = publisher
    self.continuation = continuation
  }
  
  func send(signal: Result<NetworkResponse, Error>) {
    publisher?.send(signal)
    do {
      let result = try signal.get()
      continuation?.resume(returning: result)
    } catch {
      continuation?.resume(throwing: error)
    }
  }
}
