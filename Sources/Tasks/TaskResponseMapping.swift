//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskResponseMapping {
  let mapper: NetworkResponseMapper
  
  init(mapper: NetworkResponseMapper) {
    self.mapper = mapper
  }
  
  func process(_ response: Any) async throws -> Any? {
    return try await mapper.map(response)
  }
}
