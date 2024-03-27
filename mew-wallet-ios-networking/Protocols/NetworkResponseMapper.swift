//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseMapper: Sendable {
  func map(headers: Headers?, response: any Sendable) async throws -> (any Sendable)?
}
