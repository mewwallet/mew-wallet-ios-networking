//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class TaskResponseConvertion {
  let converter: NetworkResponseConverter
  
  init(converter: NetworkResponseConverter) {
    self.converter = converter
  }
  
  func process(_ response: Any) async throws -> Any? {
    return try await converter.convert(response)
  }
}
