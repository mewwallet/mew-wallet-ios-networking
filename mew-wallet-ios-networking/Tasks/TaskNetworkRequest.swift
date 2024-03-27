//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

final class TaskNetworkRequest: Sendable {
  let client: NetworkClient
  
  init(client: NetworkClient) {
    self.client = client
  }
  
  func process(_ request: any NetworkRequest) async throws -> any Sendable {
    return try await client.send(request: request)
  }
  
  func processAndForget(_ request: NetworkRequest) async throws -> (any Sendable)? {
    try await client.sendAndForget(request: request)
  }
}
