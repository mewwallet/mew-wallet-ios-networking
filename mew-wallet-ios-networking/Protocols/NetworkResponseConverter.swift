//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseConverter: Sendable {
  func convert(_ data: any Sendable) async throws -> (any Sendable)?
}
