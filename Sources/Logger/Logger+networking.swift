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
  public static var restNetworkClient   = Logger.System.with(subsystem: "com.myetherwallet.mew-wallet-ios-networkling", category: "REST network client")
  public static var socketNetworkClient = Logger.System.with(subsystem: "com.myetherwallet.mew-wallet-ios-networkling", category: "Socket network client")
}
