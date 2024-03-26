//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 10/28/22.
//

import Foundation
import mew_wallet_ios_logger
import os

extension Logger.System {
  public static let restNetworkClient   = Logger.System.with(subsystem: "com.myetherwallet.mew-wallet-ios-networking", category: "REST network client")
  public static let socketNetworkClient = Logger.System.with(subsystem: "com.myetherwallet.mew-wallet-ios-networking", category: "Socket network client")
}
