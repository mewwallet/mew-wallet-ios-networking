//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 7/10/22.
//

import Foundation

//typealias NetworkClientResult = Result<ServerResponseModel, Error>
//typealias NetworkClientCompletionBlock = (NetworkClientResult) -> Void

protocol NetworkClient {
  func send(request: Request) async throws -> NetworkResponse
}

struct NetworkResponse {
  let response: HTTPURLResponse?
  let data: Any?
  let statusCode: Int
  
  init(_ response: HTTPURLResponse?, data: Any?, statusCode: Int) {
    self.response = response
    self.data = data
    self.statusCode = statusCode
  }
}

final class RESTClient: NetworkClient {
  enum NetworkClientError: Error {
    case invalidRequest
  }
  
  let session: URLSession
  
  init(session: URLSession) {
    self.session = session
  }
  
  func send(request: Request) async throws -> NetworkResponse {
    guard let request = request.request else { throw NetworkClientError.invalidRequest }
    let (data, response) = try await session.safeData(for: request)
    if let response = response as? HTTPURLResponse {
      return NetworkResponse(response, data: data, statusCode: response.statusCode)
    } else {
      return NetworkResponse(nil, data: data, statusCode: 200)
    }
  }
}

extension URLSession {
  func safeData(for request: URLRequest) async throws -> (Data?, URLResponse?) {
    return try await withCheckedThrowingContinuation { continuation in
      let task = self.dataTask(with: request) { data, response, error in
        if let error = error {
          continuation.resume(throwing: error)
        }
        continuation.resume(returning: (data, response))
      }
      task.resume()
    }
  }
}
