//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation
import Combine
import os
import mew_wallet_ios_logger
import mew_wallet_ios_extensions

// network layer refresh rate

public final class RESTClient: NetworkClient {
  enum NetworkClientError: Error {
    case invalidRequest
    case missingPublisher
  }
  
  let session: URLSession
  private let requestsHandler: NetworkRequestsHandler = .init()

  public init(session: URLSession) {
    self.session = session
  }
  
  public func send(request: NetworkRequest) async throws -> Any {
    guard let urlRequest = request.request as? URLRequest else { throw NetworkClientError.invalidRequest }
    
    Logger.debug(system: .restNetworkClient,
      """
      
      ==========New network task:==========
       URL: \(urlRequest.httpMethod ?? "Unknown") \(urlRequest.url?.absoluteString ?? "Unknown")
       Headers: \(urlRequest.allHTTPHeaderFields.debugDescription)
       Body: \(urlRequest.httpBody != nil ? String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? "Unknown" : "None")
      =====================================
      """
    )
    do {
      let (data, response) = try await session.safeData(for: urlRequest)
      let networkResponse: NetworkResponse
      if let response = response as? HTTPURLResponse {
        networkResponse = RESTResponse(response, data: data, statusCode: response.statusCode)
      } else {
        networkResponse = RESTResponse(nil, data: data, statusCode: .success)
      }

      if request.subscription, let publisherId = request.publisherId {
        let id = ValueWrapper.stringValue(publisherId)
        await requestsHandler.registerCommonPublisher(for: id)

        guard let storedPassthrough = await self.requestsHandler.publisher(publisherId: id)?.publisher else {
          throw NetworkClientError.missingPublisher
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
          storedPassthrough.send(.success(networkResponse))
        }
        return storedPassthrough.eraseToAnyPublisher()
      } else {
        Logger.debug(system: .restNetworkClient,
          """

          =====Network task did finished:=====
           Request: \(urlRequest.httpMethod ?? "") \(urlRequest.url?.debugDescription ?? "")
           Response: \(data != nil ? (String(data: data!, encoding: .utf8) ?? "Can't convert response to string") : "None")
          ====================================
          """)
          return networkResponse
      }
    } catch {
      Logger.error(system: .restNetworkClient,
      """
      
      =====Network task did finished:=====
       Request: \(urlRequest.httpMethod ?? "") \(urlRequest.url?.debugDescription ?? "")
       Error: \(error.localizedDescription)
      ====================================
      """)
      throw error
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
