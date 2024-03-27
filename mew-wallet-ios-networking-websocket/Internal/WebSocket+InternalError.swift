//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation

extension WebSocket {
  enum InternalError: Swift.Error, Sendable {
    case onHold
    case disconnected
  }
}
