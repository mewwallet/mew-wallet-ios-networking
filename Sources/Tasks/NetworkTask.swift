//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation
import Combine
import mew_wallet_ios_extensions

public final class NetworkTask {
  enum NetworkTaskError: Error, LocalizedError {
    case badIntermediateState
    case badCode(Int, String)
    
    var errorDescription: String? {
      switch self {
      case .badIntermediateState:         return "Bad intermediate state"
      case .badCode(_, let description):  return description
      }
    }
  }
  
  public static let shared = NetworkTask()
  
  public func run<R>(config: NetworkRequestConfig) async throws -> R {
    return try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          /// Build an request
          let builder: NetworkRequestBuilder
          switch config.request {
          case .rest:
            builder = try RESTRequestBuilder()
          case .socket:
            builder = SocketRequestBuilder()
          }
          
          let task_build = try TaskBuildNetworkRequest(builder: builder)
          let task_request = TaskNetworkRequest(client: config.client)
          
          /// Execute the request
          let request = try await task_build.process(config.request.model)
          let response = try await task_request.process(request)
          if let publisher = response as? AnyPublisher<Result<NetworkResponse, Error>, Never> {
            let mapped = publisher
              .asyncMap { [weak self] response -> Any? in
                switch response {
                case .success(let response):
                  return try await self?.process(networkResponse: response, config: config)
                case .failure(let error):
                  throw error
                }
              }
            continuation.resume(returning: mapped.eraseToAnyPublisher() as! R)
          } else if let response = response as? NetworkResponse {
            let result: R = try await process(networkResponse: response, config: config)
            continuation.resume(returning: result)
          } else if let commonPublisher = response as? AnyPublisher<(ValueWrapper, Data), Never> {
            continuation.resume(returning: commonPublisher as! R)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
  
  private func process<R>(networkResponse: NetworkResponse, config: NetworkRequestConfig) async throws -> R {
    guard case .success = networkResponse.statusCode else {
      if let body = networkResponse.data as? Data {
        throw NetworkTaskError.badCode(networkResponse.statusCode.code, String(data: body, encoding: .utf8) ?? "Unknown")
      } else {
        throw NetworkTaskError.badCode(networkResponse.statusCode.code, "No response")
      }
    }
    
    /// Deserialization
    let deserialized: Any
    switch config.deserialization {
    case .disable:
      // TODO: Throw an error?
      guard let data = networkResponse.data else {
        throw NetworkTaskError.badIntermediateState
      }
      deserialized = data
    case .custom(let deserializer):
      let task_deserialization = TaskDeserialization(deserializer: deserializer)
      deserialized = try await task_deserialization.process(networkResponse)
    }
    
    /// Validation
    switch config.validation {
    case .disable:
      break
    case .custom(let validator):
      let task_validation = TaskResponseValidation(validator: validator)
      try await task_validation.process(deserialized)
    }
    
    /// Convertion
    let converted: Any?
    switch config.conversion {
    case .disable:
      converted = deserialized
    case .custom(let converter):
      let task_convertion = TaskResponseConvertion(converter: converter)
      converted = try await task_convertion.process(deserialized)
    }
    
    /// Mapping
    let result: R
    switch config.mapping {
    case .disable:
      precondition(converted is R)
      result = converted as! R
    case .custom(let mapper):
      let task_mapping = TaskResponseMapping(mapper: mapper)
      guard let converted = converted else {
        throw NetworkTaskError.badIntermediateState
      }
      let mapped = try await task_mapping.process(converted)
      precondition(mapped is R)
      result = mapped as! R
    }
    return result
  }
}
