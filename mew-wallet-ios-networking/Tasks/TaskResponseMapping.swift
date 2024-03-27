//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskResponseMapping: Sendable {
  let mapper: NetworkResponseMapper
  
  init(mapper: NetworkResponseMapper) {
    self.mapper = mapper
  }
  
  func process(headers: Headers?, response: any Sendable) async throws -> (any Sendable)? {
    return try await mapper.map(headers: headers, response: response)
  }
}
