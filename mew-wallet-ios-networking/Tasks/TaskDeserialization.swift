//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskDeserialization: Sendable {
  let deserializer: NetworkResponseDeserializer
  
  init(deserializer: NetworkResponseDeserializer) {
    self.deserializer = deserializer
  }
  
  func process(_ response: NetworkResponse) async throws -> any Sendable {
    return try await self.deserializer.deserialize(response)
  }
}
