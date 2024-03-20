//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/3/24.
//

import Foundation

extension WebSocket {
  public struct Configuration: Sendable {
    public enum TLS: Sendable {
      case disabled
      case unpinned
      case pinned(domain: String?, allowSelfSigned: Bool)
    }
    /// Enables SSL Certificate Pinning
    public let tls: TLS
    /// An optional UInt64 representing the delay before retrying a connection in nanoseconds.
    public let reconnectDelay: UInt64?
    /// Automatically handle ping-pong loop
    public let autoReplyPing: Bool
    /// Interval between ping messages
    public let pingInterval: TimeInterval?
    
    public static let `default` = WebSocket.Configuration(
      tls: .pinned(domain: nil, allowSelfSigned: false),
      reconnectDelay: 5.0,
      autoReplyPing: true,
      pingInterval: 20.0
    )
    
    public static let defaultNoPinning = WebSocket.Configuration(
      tls: .disabled,
      reconnectDelay: 5.0,
      autoReplyPing: true,
      pingInterval: 20.0
    )
    
    public init(tls: TLS, reconnectDelay: TimeInterval?, autoReplyPing: Bool, pingInterval: TimeInterval?) {
      self.tls = tls
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
