//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public final class RESTClient: NetworkClient {
  enum NetworkClientError: Error {
    case invalidRequest
  }
  
  let session: URLSession
  
  public init(session: URLSession) {
    self.session = session
  }
  
  func send(request: NetworkRequest) async throws -> NetworkResponse {
    guard let request = request.request as? URLRequest else { throw NetworkClientError.invalidRequest }
    let (data, response) = try await session.safeData(for: request)
    if let response = response as? HTTPURLResponse {
      return RESTResponse(response, data: data, statusCode: response.statusCode)
    } else {
      return RESTResponse(nil, data: data, statusCode: .success)
    }
  }
}

extension URLSession {
  func safeData(for request: URLRequest) async throws -> (Data?, URLResponse?) {
    return try await withCheckedThrowingContinuation { continuation in
      let task = self.dataTask(with: request) { data, response, error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: (data, response))
      }
      task.resume()
    }
  }
}
