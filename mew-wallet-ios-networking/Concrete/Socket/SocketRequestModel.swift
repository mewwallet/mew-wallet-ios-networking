//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct SocketRequestModel: NetworkRequestModel {
  public let subscription: Bool
  public var body: (any Sendable)?
  public var publisherId: String?
  
  public init(
    subscription: Bool,
    body: (any Sendable)? = nil,
    publisherId: String? = nil
  ) {
    self.subscription = subscription
    self.body = body
    self.publisherId = publisherId
  }
}
