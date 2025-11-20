//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation

extension MW.WebSocket {
  internal final class Consumer: Sendable, Equatable {
    let uuid: UUID
    let continuation: AsyncStream<Event>.Continuation
    static func == (lhs: MW.WebSocket.Consumer, rhs: MW.WebSocket.Consumer) -> Bool { lhs.uuid == rhs.uuid }
    
    init(continuation: AsyncStream<Event>.Continuation, termination: (@Sendable (Consumer, AsyncStream<Event>.Continuation.Termination) -> Void)?) {
      let uuid = UUID()
      self.uuid = uuid
      
      self.continuation = continuation
      
      continuation.onTermination = {[weak self] reason in
        guard let self else { return }
        termination?(self, reason)
      }
    }
  }
}
