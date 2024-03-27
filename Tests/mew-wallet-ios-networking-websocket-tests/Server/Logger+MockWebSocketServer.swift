//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/18/24.
//

import Foundation
import wcpm_logger
import os

extension Logger.System {
  public static let mockWebSocketServer     = Logger.System.with(subsystem: "wcpm-networking.websocket", category: "MockWebSocketServer", level: .debug)
}
