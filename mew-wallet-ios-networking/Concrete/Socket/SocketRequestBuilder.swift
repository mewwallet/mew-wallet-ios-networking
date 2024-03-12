//
//  File.swift
//  
//
//  Created by Nail Galiaskarov on 9/22/22.
//

import Foundation

final class SocketRequestBuilder: NetworkRequestBuilder {
  func build(with config: NetworkRequestModel) async throws -> any NetworkRequest {
    guard let config = config as? SocketRequestModel else {
      throw SocketClientError.badFormat
    }

    var socketRequest = SocketRequest(request: config.body)
    socketRequest.subscription = config.subscription
    socketRequest.publisherId = config.publisherId
    return socketRequest
  }
}
