//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseDeserializer {
  func deserialize<T>(_ data: NetworkResponse?) async throws -> T
}
