//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation

extension MW.WebSocket {
  public enum ConnectionError: Swift.Error, Sendable {
    case notReachable
  }
}
