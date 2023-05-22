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

public final class RESTClient: NetworkClient {
  enum NetworkClientError: Error {
    case invalidRequest
  }
  
  let session: URLSession
  
  public init(session: URLSession) {
    self.session = session
  }
  
  public func send(request: NetworkRequest) async throws -> Any {
    guard let request = request.request as? URLRequest else { throw NetworkClientError.invalidRequest }
    
    Logger.debug(.restNetworkClient,
      """
      
      ==========New network task:==========
       URL: \(request.httpMethod ?? "Unknown") \(request.url?.absoluteString ?? "Unknown")
       Headers: \(request.allHTTPHeaderFields.debugDescription)
       Body: \(request.httpBody != nil ? String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "Unknown" : "None")
      =====================================
      """
    )
    do {
      let (data, response) = try await session.safeData(for: request)
      
      Logger.debug(.restNetworkClient,
        """
        
        =====Network task did finished:=====
         Request: \(request.httpMethod ?? "") \(request.url?.debugDescription ?? "")
         Response: \(data != nil ? (String(data: data!, encoding: .utf8) ?? "Can't convert response to string") : "None")
        ====================================
        """)
      if let response = response as? HTTPURLResponse {
        return RESTResponse(response, data: data, statusCode: response.statusCode)
      } else {
        return RESTResponse(nil, data: data, statusCode: .success)
      }
    } catch {
      Logger.error(.restNetworkClient,
      """
      
      =====Network task did finished:=====
       Request: \(request.httpMethod ?? "") \(request.url?.debugDescription ?? "")
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
