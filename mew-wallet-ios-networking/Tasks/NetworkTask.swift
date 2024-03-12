//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation
import mew_wallet_ios_extensions

public final class NetworkTask: Sendable {
  public enum Error: LocalizedError, Equatable {
    case aborted
    case badIntermediateState
    case code_400_badRequest(response: String)
    case code_403_forbidden(response: String)
    case code_404_notFound(response: String)
    case code_406_notAcceptable(response: String)
    case code_409_conflict(response: String)
    case code_424_failedDependency(response: String)
    case code_426_upgradeRequired(response: String)
    case code_429_awsTooManyRequests(response: String)
    case badCode(code: Int, response: String)
    
    init(code: Int, response: String) {
      switch code {
      case NetworkResponseCode.badRequest.code:                 self = .code_400_badRequest(response: response)
      case NetworkResponseCode.conflict.code:                   self = .code_409_conflict(response: response)
      case NetworkResponseCode.notFound.code:                   self = .code_404_notFound(response: response)
      case NetworkResponseCode.notAcceptable.code:              self = .code_406_notAcceptable(response: response)
      case NetworkResponseCode.failedDependency.code:           self = .code_424_failedDependency(response: response)
      case NetworkResponseCode.aws_tooManyRequests.code:        self = .code_429_awsTooManyRequests(response: response)
      default:                                                  self = .badCode(code: code, response: response)
      }
    }
    
    public var errorDescription: String? {
      switch self {
      case .aborted:                                            return "Aborted"
      case .badIntermediateState:                               return "Bad intermediate state"
      case .badCode(let code, let description):                 return "\(code): \(description)"
      case .code_400_badRequest(let response):                  return "400: \(response)"
      case .code_403_forbidden(response: let response):         return "403: \(response)"
      case .code_404_notFound(let response):                    return "404: \(response)"
      case .code_406_notAcceptable(let response):               return "406: \(response)"
      case .code_409_conflict(let response):                    return "409: \(response)"
      case .code_424_failedDependency(let response):            return "424: \(response)"
      case .code_426_upgradeRequired(response: let response):   return "426: \(response)"
      case .code_429_awsTooManyRequests(let response):          return "429: \(response)"
      }
    }
  }
  
  public static func run<R>(config: NetworkRequestConfig) async throws -> R {
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
          
          if R.self == Void.self {
            if let response = try await task_request.processAndForget(request) {
              if let response = response as? NetworkResponse {
                try self.checkForError(networkResponse: response, config: config)
                continuation.resume(returning: () as! R)
              } else {
                continuation.resume(throwing: NetworkTask.Error.badIntermediateState)
              }
            } else {
              continuation.resume(returning: () as! R)
            }
          } else {
            let response = try await task_request.process(request)
            if let publisher = response as? BroadcastAsyncStream<Result<any NetworkResponse, any Swift.Error>> {
              let mapped = publisher
                .mapValues { response -> (any Sendable)? in
                  switch response {
                  case .success(let response):
                    return try await self.process(networkResponse: response, config: config)
                  case .failure(let error):
                    throw error
                  }
                }
              continuation.resume(returning: mapped as! R)
            } else if let response = response as? NetworkResponse {
              let result: R = try await self.process(networkResponse: response, config: config)
              continuation.resume(returning: result)
            } else if let commonPublisher = response as? BroadcastAsyncStream<(IDWrapper, Data)> {
              continuation.resume(returning: commonPublisher as! R)
            } else {
              continuation.resume(throwing: NetworkTask.Error.badIntermediateState)
            }
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
  
  static private func checkForError(networkResponse: NetworkResponse, config: NetworkRequestConfig) throws {
    guard networkResponse.statusCode.isSuccess else {
      if let body = networkResponse.data as? Data {
        throw Error(code: networkResponse.statusCode.code, response: String(data: body, encoding: .utf8) ?? "Unknown")
      } else {
        throw Error(code: networkResponse.statusCode.code, response: "No response")
      }
    }
  }
  
  static private func process<R>(networkResponse: NetworkResponse, config: NetworkRequestConfig) async throws -> R {
    try self.checkForError(networkResponse: networkResponse, config: config)
    
    /// Deserialization
    let deserialized: any Sendable
    switch config.deserialization {
    case .disable:
      // TODO: Throw an error?
      guard let data = networkResponse.data else {
        throw NetworkTask.Error.badIntermediateState
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
    let converted: (any Sendable)?
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
        throw NetworkTask.Error.badIntermediateState
      }
      let mapped = try await task_mapping.process(headers: networkResponse.response?.allHeaderFields as? Headers, response: converted)
      precondition(mapped is R)
      result = mapped as! R
    }
    return result
  }
}
