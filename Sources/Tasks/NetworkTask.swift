//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

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
  
  public func run(config: NetworkRequestConfig) async throws -> Any? {
    return try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          /// Build an request
          let builder: NetworkRequestBuilder
          switch config.request {
          case .rest:
            builder = try RESTRequestBuilder()
          case .socket:
            // FIXME: builder
            builder = try RESTRequestBuilder()
          }
          
          let task_build = try TaskBuildNetworkRequest(builder: builder)
          let task_request = TaskNetworkRequest(client: config.client)
          
          /// Execute the request
          let request = try await task_build.process(config.request.model)
          let response = try await task_request.process(request)
          guard case .success = response.statusCode else {
            if let body = response.data as? Data {
              throw NetworkTaskError.badCode(response.statusCode.code, String(data: body, encoding: .utf8) ?? "Unknown")
            } else {
              throw NetworkTaskError.badCode(response.statusCode.code, "No response")
            }
          }
          
          /// Deserialization
          let deserialized: Any
          switch config.deserialization {
          case .disable:
            // TODO: Throw an error?
            guard let data = response.data else {
              continuation.resume(throwing: NetworkTaskError.badIntermediateState)
              return
            }
            deserialized = data
          case .custom(let deserializer):
            let task_deserialization = TaskDeserialization(deserializer: deserializer)
            deserialized = try await task_deserialization.process(response)
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
          let result: Any?
          switch config.mapping {
          case .disable:
            result = converted
          case .custom(let mapper):
            let task_mapping = TaskResponseMapping(mapper: mapper)
            guard let converted = converted else {
              continuation.resume(throwing: NetworkTaskError.badIntermediateState)
              return
            }
            result = try await task_mapping.process(converted)
          }
          
          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
