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
  public enum Error: LocalizedError, Equatable {
    case badIntermediateState
    case code_400_badRequest(response: String)
    case code_404_notFound(response: String)
    case code_409_conflict(response: String)
    case code_429_awsTooManyRequests(response: String)
    case badCode(code: Int, response: String)
    
    init(code: Int, response: String) {
      switch code {
      case NetworkResponseCode.badRequest.code:           self = .code_400_badRequest(response: response)
      case NetworkResponseCode.conflict.code:             self = .code_409_conflict(response: response)
      case NetworkResponseCode.notFound.code:             self = .code_404_notFound(response: response)
      case NetworkResponseCode.aws_tooManyRequests.code:  self = .code_429_awsTooManyRequests(response: response)
      default:                                            self = .badCode(code: code, response: response)
      }
    }
    
    public var errorDescription: String? {
      switch self {
      case .badIntermediateState:                         return "Bad intermediate state"
      case .badCode(let code, let description):           return "\(code): \(description)"
      case .code_400_badRequest(let response):            return "400: \(response)"
      case .code_404_notFound(let response):              return "404: \(response)"
      case .code_409_conflict(let response):              return "409: \(response)"
      case .code_429_awsTooManyRequests(let response):    return "429: \(response)"
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
          if let publisher = response as? AnyPublisher<Result<NetworkResponse, Swift.Error>, Never> {
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
    guard networkResponse.statusCode.isSuccess else {
      if let body = networkResponse.data as? Data {
        throw Error(code: networkResponse.statusCode.code, response: String(data: body, encoding: .utf8) ?? "Unknown")
      } else {
        throw Error(code: networkResponse.statusCode.code, response: "No response")
      }
    }
    
    /// Deserialization
    let deserialized: Any
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
        throw NetworkTask.Error.badIntermediateState
      }
      let mapped = try await task_mapping.process(converted)
      precondition(mapped is R)
      result = mapped as! R
    }
    return result
  }
}
