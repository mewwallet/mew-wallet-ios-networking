//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

final class TaskNetworkRequest {
  let client: NetworkClient
  
  init(client: NetworkClient) {
    self.client = client
  }
  
  func process(_ request: NetworkRequest) async throws -> NetworkResponse {
    return try await client.send(request: request)
  }
}
