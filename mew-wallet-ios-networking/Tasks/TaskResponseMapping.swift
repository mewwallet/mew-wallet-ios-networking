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
  
  func process(responseCode: NetworkResponseCode, headers: Headers?, response: any Sendable) async throws -> (any Sendable)? {
    return try await mapper.map(responseCode: responseCode, headers: headers, response: response)
  }
}
