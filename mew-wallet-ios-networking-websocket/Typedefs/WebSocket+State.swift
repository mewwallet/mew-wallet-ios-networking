//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation

extension WebSocket {
  public enum State: Sendable {
    case disconnected
    case pending
    case connected
  }
}
