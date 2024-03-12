//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation
import Combine

public protocol NetworkClient: Sendable {
  func send(request: any NetworkRequest) async throws -> any Sendable
  @discardableResult func sendAndForget(request: NetworkRequest) async throws -> (any Sendable)?
}
