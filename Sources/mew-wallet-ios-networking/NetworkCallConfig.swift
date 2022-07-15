//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 7/10/22.
//

import Foundation

struct NetworkCallConfig {
  let requestModel: RequestModel
}

struct RequestModel {
  enum Method: RawRepresentable {
    var rawValue: String {
      switch self {
      case .get: return "GET"
      case .post: return "POST"
      case .custom(let method): return method
      }
    }
    
    init(rawValue: String) {
      switch rawValue {
      case "GET": self = .get
      case "POST": self = .post
      default: self = .custom(rawValue)
      }
    }
    
    case get
    case post
    case custom(String)
  }
  public var baseURL: URL?
  public var networkPath: NetworkPath?
  public var method: Method = .get
  public var headers: [String:String?]?
  public var body: Data?
  
  func baseURL(_ url :URL?) -> Self {
    var `self` = self
    `self`.baseURL = url
    return `self`
  }
  
  func networkPath(path: NetworkPath) -> Self {
    var `self` = self
    `self`.networkPath = path
    return `self`
  }
  
  func method(_ method: Method) -> Self {
    var `self` = self
    `self`.self.method = method
    return `self`
  }
  
  func body(_ body: Data?) -> Self {
    var `self` = self
    `self`.self.body = body
    return `self`
  }
  
  func headers(_ headers: [String: String?]?) -> Self {
    var `self` = self
    `self`.self.headers = headers
    return `self`
  }
}

protocol NetworkPath {
  var path: String { get }
  var query: [URLQueryItem]? { get }
}

struct Request {
  let request: URLRequest?
}

protocol NetworkCallBuilder {
  func build(with config: RequestModel) async throws -> Request
}

final class RESTNetworkCallBuilder: NetworkCallBuilder {
  public enum BuilderError: Error {
    case invalidURL
  }
  
  private let baseComponents: URLComponents
  
  init(baseURL: URL?, path: String?) throws {
    var initComponents: URLComponents
    if let baseURL = baseURL {
      guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw BuilderError.invalidURL }
      initComponents = components
    } else {
      initComponents = URLComponents()
    }
    
    if let path = path {
      initComponents.path = path
    }
    
    baseComponents = initComponents
  }
  
  func build(with config: RequestModel) async throws -> Request {
    var components: URLComponents
    
    if let url = config.baseURL {
      guard let configComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw BuilderError.invalidURL }
      components = configComponents
    } else {
      components = self.baseComponents
    }
    
    if let path = config.networkPath?.path { components.path = path.hasPrefix("/") ? path : "/" + path }
    if let queryItems = config.networkPath?.query { components.queryItems = queryItems }
    guard let url = components.url else { throw BuilderError.invalidURL }
    var request = URLRequest(url: url)
    if let body = config.body { request.httpBody = body }
    request.httpMethod = config.method.rawValue
    config.headers?.forEach {
      request.setValue($0.value, forHTTPHeaderField: $0.key)
    }
    return Request(request: request)
  }
}


//
//    if let headers = requestDataModel?.headerFields {
//      for header in headers {
//        urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
//      }
//    }
//
//    return .success(urlRequest)
//  }
//}
//
//extension URLComponents {
//  mutating func setQueryItems(with parameters: [String: String]) {
//    self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
//  }
//}

//
//struct CompoundOperationBuilderConfig {
//  // MARK: - General parameters
//  let inputData: Any?
//
//  // MARK: - Request configuration operation parameters
//  let requestConfigurationType: RequestConfiguratorType
//  let requestMethod: NetworkHTTPMethod
//  let requestService: String?
//  let requestURLParameters: [String]?
//  let requestSubscription: Bool
//
//  // MARK: - Request network client
//  let networkClientType: NetworkClientType
//
//  // MARK: - Response deserialization operation parameters
//  let responseDeserializationType: ResponseDeserializerType
//
//  // MARK: - Validation operation parameters
//  let responseValidationType: ResponseValidatorType
//
//  // MARK: - Response converting operation parameters
//  let responseConvertingType: ResponseConverterType
//
//  // MARK: - Mapping operation type
//  let responseMappingType: ResponseMapperType
//  let responseMappingContext: ResponseMappingContext?
//  let responseMappingType2: ResponseMapperType
//  let responseMappingContext2: ResponseMappingContext?
//
//  init(inputData: Any?,
//       requestConfigurationType: RequestConfiguratorType,
//       requestMethod: NetworkHTTPMethod,
//       requestService: String?,
//       requestURLParameters: [String]?,
//       requestSubscription: Bool,
//       networkClientType: NetworkClientType,
//       responseDeserializationType: ResponseDeserializerType,
//       responseValidationType: ResponseValidatorType,
//       responseConvertingType: ResponseConverterType,
//       responseMappingType: ResponseMapperType,
//       responseMappingContext: ResponseMappingContext?,
//       responseMappingType2: ResponseMapperType = .disabled,
//       responseMappingContext2: ResponseMappingContext? = nil) {
//    self.inputData                      = inputData
//    self.requestConfigurationType       = requestConfigurationType
//    self.requestMethod                  = requestMethod
//    self.requestService                 = requestService
//    self.requestURLParameters           = requestURLParameters
//    self.requestSubscription            = requestSubscription
//    self.networkClientType              = networkClientType
//    self.responseDeserializationType    = responseDeserializationType
//    self.responseValidationType         = responseValidationType
//    self.responseConvertingType         = responseConvertingType
//    self.responseMappingType            = responseMappingType
//    self.responseMappingContext         = responseMappingContext
//    self.responseMappingType2           = responseMappingType2
//    self.responseMappingContext2        = responseMappingContext2
//  }
//}
