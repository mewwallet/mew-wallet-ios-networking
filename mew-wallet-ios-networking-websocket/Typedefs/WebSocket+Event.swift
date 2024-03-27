//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation
import Network

extension WebSocket {
  public enum Event: Sendable, Equatable {
    case connected
    case disconnected
    case viabilityDidChange(_ isViable: Bool)
    case ping
    case pong
    case text(String?)
    case binary(Data?)
    case error(NWError)
    case connectionError(ConnectionError)
  }
}
