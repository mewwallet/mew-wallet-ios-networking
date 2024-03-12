//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskResponseConvertion: Sendable {
  let converter: NetworkResponseConverter
  
  init(converter: NetworkResponseConverter) {
    self.converter = converter
  }
  
  func process(_ response: any Sendable) async throws -> (any Sendable)? {
    return try await converter.convert(response)
  }
}
