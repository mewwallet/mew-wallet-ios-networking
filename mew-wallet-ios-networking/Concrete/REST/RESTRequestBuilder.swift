//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

final class RESTRequestBuilder: NetworkRequestBuilder {
  public enum BuilderError: Error {
    case invalidModel
    case invalidURL
  }
  
  private let baseComponents: URLComponents
  
  init(baseURL: URL? = nil, path: String? = nil) throws {
    var initComponents: URLComponents
    if let baseURL = baseURL {
      guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw BuilderError.invalidURL }
      initComponents = components
    } else {
      initComponents = URLComponents()
    }
    
    if let path = path, !path.isEmpty {
      if !initComponents.path.hasSuffix("/"), !path.hasPrefix("/") {
        initComponents.path += "/" + path
      } else {
        initComponents.path += path
      }
    }
    
    baseComponents = initComponents
  }
  
  func build(with config: NetworkRequestModel) async throws -> NetworkRequest {
    guard let config = config as? RESTRequestModel else { throw BuilderError.invalidModel }
    var components: URLComponents
    
    if let url = config.baseURL {
      guard let configComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw BuilderError.invalidURL }
      components = configComponents
    } else {
      components = self.baseComponents
    }
    
    if let path = config.networkPath?.path, !path.isEmpty {
      if !components.path.hasSuffix("/"), !path.hasPrefix("/") {
        components.path += "/" + path
      } else {
        components.path += path
      }
    }
    if let queryItems = try config.networkPath?.query { components.queryItems = queryItems }
    guard let url = components.url else { throw BuilderError.invalidURL }
    var request = URLRequest(url: url)
    if let body = config.body { request.httpBody = body }
    request.httpMethod = config.method.rawValue
    config.headers?.forEach {
      request.setValue($0.value, forHTTPHeaderField: $0.key)
    }
    return RESTRequest(request: request)
  }
}
