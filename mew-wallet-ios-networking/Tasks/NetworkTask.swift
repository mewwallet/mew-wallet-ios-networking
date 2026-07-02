//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation
import mew_wallet_ios_extensions

public final class NetworkTask: Sendable {
  public typealias Error = NetworkTask.TypedError<String>
  
  public enum TypedError<T: Sendable & Equatable>: Sendable, LocalizedError, Equatable {
    case aborted
    case badIntermediateState
    case code_400_badRequest(response: T?)
    case code_403_forbidden(response: T?)
    case code_404_notFound(response: T?)
    case code_406_notAcceptable(response: T?)
    case code_409_conflict(response: T?)
    case code_423_locked(response: T?)
    case code_424_failedDependency(response: T?)
    case code_426_upgradeRequired(response: T?)
    case code_429_awsTooManyRequests(response: T?)
    case badCode(code: Int, response: T?)
    case underlying(any Swift.Error)
    
    init(code: Int, response: T?) {
      switch code {
      case NetworkResponseCode.badRequest.code:                 self = .code_400_badRequest(response: response)
      case NetworkResponseCode.forbidden.code:                  self = .code_403_forbidden(response: response)
      case NetworkResponseCode.notFound.code:                   self = .code_404_notFound(response: response)
      case NetworkResponseCode.notAcceptable.code:              self = .code_406_notAcceptable(response: response)
      case NetworkResponseCode.conflict.code:                   self = .code_409_conflict(response: response)
      case NetworkResponseCode.locked.code:                     self = .code_423_locked(response: response)
      case NetworkResponseCode.failedDependency.code:           self = .code_424_failedDependency(response: response)
      case NetworkResponseCode.upgradeRequired.code:            self = .code_426_upgradeRequired(response: response)
      case NetworkResponseCode.aws_tooManyRequests.code:        self = .code_429_awsTooManyRequests(response: response)
      default:                                                  self = .badCode(code: code, response: response)
      }
    }
    
    public var errorDescription: String? {
      switch self {
      case .aborted:                                            return "Aborted"
      case .badIntermediateState:                               return "Bad intermediate state"
      case .badCode(let code, let description):                 return "\(code): \(String(describing: description))"
      case .code_400_badRequest(let response):                  return "400: \(String(describing: response))"
      case .code_403_forbidden(response: let response):         return "403: \(String(describing: response))"
      case .code_404_notFound(let response):                    return "404: \(String(describing: response))"
      case .code_406_notAcceptable(let response):               return "406: \(String(describing: response))"
      case .code_409_conflict(let response):                    return "409: \(String(describing: response))"
      case .code_423_locked(let response):                      return "423: \(String(describing: response))"
      case .code_424_failedDependency(let response):            return "424: \(String(describing: response))"
      case .code_426_upgradeRequired(response: let response):   return "426: \(String(describing: response))"
      case .code_429_awsTooManyRequests(let response):          return "429: \(String(describing: response))"
      case .underlying(let error):                              return "Underlying: \(error)"
      }
    }
    
    public static func == (lhs: TypedError<T>, rhs: TypedError<T>) -> Bool {
      switch (lhs, rhs) {
      case (.aborted,                             .aborted):                                return true
      case (.badIntermediateState,                .badIntermediateState):                   return true
      case (.code_400_badRequest(let l),          .code_400_badRequest(let r)):             return l == r
      case (.code_403_forbidden(let l),           .code_403_forbidden(let r)):              return l == r
      case (.code_404_notFound(let l),            .code_404_notFound(let r)):               return l == r
      case (.code_406_notAcceptable(let l),       .code_406_notAcceptable(let r)):          return l == r
      case (.code_409_conflict(let l),            .code_409_conflict(let r)):               return l == r
      case (.code_423_locked(let l),              .code_423_locked(let r)):                 return l == r
      case (.code_424_failedDependency(let l),    .code_424_failedDependency(let r)):       return l == r
      case (.code_426_upgradeRequired(let l),     .code_426_upgradeRequired(let r)):        return l == r
      case (.code_429_awsTooManyRequests(let l),  .code_429_awsTooManyRequests(let r)):     return l == r
      case (.badCode(let lCode, let lResponse),   .badCode(let rCode, let rResponse)):      return lCode == rCode && lResponse == rResponse
      case (.underlying,                          .underlying):                             return false // Cannot compare arbitrary errors
      default:
        return false
      }
    }
  }
  
  public static func run<R: Sendable, E: Sendable & Equatable>(config: NetworkRequestConfig) async throws(TypedError<E>) -> R {
    let result: Result<R, TypedError<E>> = await self._run(config: config)
    return try result.get()
  }
  
  public static func runResult<R: Sendable, E: Sendable & Equatable>(config: NetworkRequestConfig) async -> Result<R, TypedError<E>> {
    let result: Result<R, TypedError<E>> = await self._run(config: config)
    return result
  }
  
  public static func run<R: Sendable>(config: NetworkRequestConfig) async throws -> R {
    do {
      let result: Result<R, NetworkTask.Error> = await self._run(config: config)
      return try result.get()
    } catch {
      switch error {
      case .underlying(let error):
        throw error
      default:
        throw error
      }
    }
  }
  
  // MARK: - Private
  
  private static func _run<R: Sendable, E: Sendable & Equatable>(config: NetworkRequestConfig) async -> Result<R, TypedError<E>> {
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
            try await self.checkForError(networkResponse: response, config: config, errorType: E.self)
            return .success(() as! R)
          } else {
            throw TypedError<E>.badIntermediateState
          }
        } else {
          return .success(() as! R)
        }
      } else {
        let response = try await task_request.process(request)
        if let publisher = response as? BroadcastAsyncStream<Result<any NetworkResponse, any Swift.Error>> {
          let mapped = publisher
            .mapValues { response -> (any Sendable)? in
              switch response {
              case .success(let response):
                return try await self.process(networkResponse: response, config: config, errorType: E.self)
              case .failure(let error):
                throw error
              }
            }
          return .success(mapped as! R)
        } else if let response = response as? NetworkResponse {
          let result: R = try await self.process(networkResponse: response, config: config, errorType: E.self)
          return .success(result)
        } else if let commonPublisher = response as? BroadcastAsyncStream<(IDWrapper, Data)> {
          return .success(commonPublisher as! R)
        } else {
          throw TypedError<E>.badIntermediateState
        }
      }
    } catch {
      return .failure(TypedError.underlying(error))
    }
  }
  
  static private func checkForError<E: Sendable & Equatable>(networkResponse: NetworkResponse, config: NetworkRequestConfig, errorType: E.Type) async throws(TypedError<E>) {
    guard !networkResponse.statusCode.isSuccess else { return }
    
    guard let body = networkResponse.data as? Data else {
      throw TypedError(code: networkResponse.statusCode.code, response: nil)
    }
    
    switch errorType {
    case is String.Type:
      let errorString = String(data: body, encoding: .utf8) ?? "Unknown error"
      throw TypedError(code: networkResponse.statusCode.code, response: errorString as? E)
      
    case is Never.Type:
      /// This will loop the call to `String.Type` and keep backward compatibility.
      do {
        try await self.checkForError(networkResponse: networkResponse, config: config, errorType: String.self)
      } catch {
        throw TypedError.underlying(error)
      }
      
    default:
      /// Mapping
      let result: E
      switch config.mapping {
      case .disable:
        precondition(body is E)
        result = body as! E
      case .custom(let mapper):
        let task_mapping = TaskResponseMapping(mapper: mapper)
        do {
          let mapped = try await task_mapping.process(
            responseCode: networkResponse.statusCode,
            headers: networkResponse.response?.allHeaderFields as? Headers,
            response: body
          )
          precondition(mapped is E)
          result = mapped as! E
        } catch {
          throw TypedError<E>.underlying(error)
        }
      }
      throw TypedError(code: networkResponse.statusCode.code, response: result)
    }
  }
  
  static private func process<R, E: Sendable & Equatable>(networkResponse: NetworkResponse, config: NetworkRequestConfig, errorType: E.Type) async throws(TypedError<E>) -> R {
    try await self.checkForError(networkResponse: networkResponse, config: config, errorType: E.self)
    
    /// Deserialization
    let deserialized: any Sendable
    switch config.deserialization {
    case .disable:
      // TODO: Throw an error?
      guard let data = networkResponse.data else {
        throw TypedError<E>.badIntermediateState
      }
      deserialized = data
    case .custom(let deserializer):
      let task_deserialization = TaskDeserialization(deserializer: deserializer)
      do {
        deserialized = try await task_deserialization.process(networkResponse)
      } catch {
        throw TypedError<E>.underlying(error)
      }
    }
    
    /// Validation
    switch config.validation {
    case .disable:
      break
    case .custom(let validator):
      let task_validation = TaskResponseValidation(validator: validator)
      do {
        try await task_validation.process(deserialized)
      } catch {
        throw TypedError<E>.underlying(error)
      }
    }
    
    /// Convertion
    let converted: (any Sendable)?
    switch config.conversion {
    case .disable:
      converted = deserialized
    case .custom(let converter):
      let task_convertion = TaskResponseConvertion(converter: converter)
      do {
        converted = try await task_convertion.process(deserialized)
      } catch {
        throw TypedError<E>.underlying(error)
      }
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
        throw TypedError<E>.badIntermediateState
      }
      do {
        let mapped = try await task_mapping.process(
          responseCode: networkResponse.statusCode,
          headers: networkResponse.response?.allHeaderFields as? Headers,
          response: converted
        )
        precondition(mapped is R)
        result = mapped as! R
      } catch {
        throw TypedError<E>.underlying(error)
      }
    }
    return result
  }
}
