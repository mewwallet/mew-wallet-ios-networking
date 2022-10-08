//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct SocketRequestModel: NetworkRequestModel {
  public let subscription: Bool
  public var body: Any?
  public var useCommonMessagePublisher: Bool
  
  public init(
    subscription: Bool,
    body: Any? = nil,
    useCommonMessagePublisher: Bool = false
  ) {
    self.subscription = subscription
    self.body = body
    self.useCommonMessagePublisher = useCommonMessagePublisher
  }
}
