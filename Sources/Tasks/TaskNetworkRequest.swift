//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation
import Combine

final class TaskNetworkRequest {
  let client: NetworkClient
  
  init(client: NetworkClient) {
    self.client = client
  }
  
  func process(_ request: NetworkRequest) async throws -> Any {
    return try await client.send(request: request)
  }
}
