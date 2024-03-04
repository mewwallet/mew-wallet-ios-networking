//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/3/24.
//

import Foundation

extension WebSocket {
  public struct Configuration {
    /// Enables SSL Certificate Pinning
    public let certificatePinning: Bool
    /// An optional UInt64 representing the delay before retrying a connection in nanoseconds.
    public let reconnectDelay: UInt64?
    /// Automatically handle ping-pong loop
    public let autoReplyPing: Bool
    public let pingInterval: TimeInterval?
    
    public static let `default` = WebSocket.Configuration(
      certificatePinning: true,
      reconnectDelay: 3.0,
      autoReplyPing: true,
      pingInterval: 10.0
    )
    
    public init(certificatePinning: Bool, reconnectDelay: TimeInterval?, autoReplyPing: Bool, pingInterval: TimeInterval?) {
      self.certificatePinning = certificatePinning
      if let reconnectDelay {
        self.reconnectDelay = UInt64(reconnectDelay * 1_000_000_000)
      } else {
        self.reconnectDelay = nil
      }
      self.autoReplyPing = autoReplyPing
      self.pingInterval = pingInterval
    }
  }
}
