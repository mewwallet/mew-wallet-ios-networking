//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskDeserialization {
  let deserializer: NetworkResponseDeserializer
  
  init(deserializer: NetworkResponseDeserializer) {
    self.deserializer = deserializer
  }
  
  func process<T>(_ response: NetworkResponse) async throws -> T {
    return try await self.deserializer.deserialize(response)
  }
}
