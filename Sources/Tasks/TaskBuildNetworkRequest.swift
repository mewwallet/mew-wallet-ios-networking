//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

final class TaskBuildNetworkRequest {
  let builder: NetworkRequestBuilder
  
  init(builder: NetworkRequestBuilder) throws {
    self.builder = builder
  }
  
  func process(_ model: NetworkRequestModel) async throws -> NetworkRequest {
    return try await builder.build(with: model)
  }
}
