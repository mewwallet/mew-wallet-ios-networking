//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct SocketRequestModel: NetworkRequestModel {
  public var body: Any?
  public init(
    body: Any? = nil
  ) {
    self.body = body
  }
}
