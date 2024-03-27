//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation

extension WebSocket {
  public enum ConnectionError: Swift.Error, Sendable {
    case notReachable
  }
}
