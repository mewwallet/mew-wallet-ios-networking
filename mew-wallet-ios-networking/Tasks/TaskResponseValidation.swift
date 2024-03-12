//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskResponseValidation: Sendable {
  let validator: NetworkResponseValidator
  
  init(validator: NetworkResponseValidator) {
    self.validator = validator
  }
  
  func process(_ response: any Sendable) async throws {
    try await validator.validate(response)
  }
}
