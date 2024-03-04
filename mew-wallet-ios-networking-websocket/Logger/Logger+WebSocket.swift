//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 2/29/24.
//

import Foundation
import mew_wallet_ios_logger
import os

extension Logger.System {
  public static let webSocket     = Logger.System.with(subsystem: "com.myetherwallet.mew-wallet-ios-networking.websocket", category: "WebSocket")
  public static let connectivity  = Logger.System.with(subsystem: "com.myetherwallet.mew-wallet-ios-networking.websocket.connectivity", category: "WebSocket. Connectivity")
}
