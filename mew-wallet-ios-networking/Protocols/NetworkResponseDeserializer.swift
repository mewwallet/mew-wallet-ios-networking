//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseDeserializer: Sendable {
  func deserialize(_ data: NetworkResponse) async throws -> any Sendable
}
