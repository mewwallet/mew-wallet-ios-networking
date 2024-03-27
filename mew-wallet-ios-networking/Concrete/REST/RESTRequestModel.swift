//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct RESTRequestModel: NetworkRequestModel {
  /// REST method, f.e. 'GET', 'POST'
  public enum Method: RawRepresentable, Sendable {
    public var rawValue: String {
      switch self {
      case .get:                  return "GET"
      case .post:                 return "POST"
      case .put:                  return "PUT"
      case .patch:                return "PATCH"
      case .delete:               return "DELETE"
      case .custom(let method):   return method
      }
    }
    
    public init(rawValue: String) {
      switch rawValue {
      case "GET":                 self = .get
      case "POST":                self = .post
      case "PUT":                 self = .put
      case "PATCH":               self = .patch
      case "DELETE":              self = .delete
      default:                    self = .custom(rawValue)
      }
    }
    
    case get
    case post
    case put
    case patch
    case delete
    case custom(String)
  }
  
  // MARK: - Public
  
  public var baseURL: URL?
  public var networkPath: NetworkPath?
  public var method: Method = .get
  public var headers: Headers?
  public var body: Data?
  
  // MARK: - Modifiers
  
  public func baseURL(_ url :URL?) -> Self {
    var `self` = self
    `self`.baseURL = url
    return `self`
  }
  
  public func networkPath(path: NetworkPath) -> Self {
    var `self` = self
    `self`.networkPath = path
    return `self`
  }
  
  public func method(_ method: Method) -> Self {
    var `self` = self
    `self`.self.method = method
    return `self`
  }
  
  public func body(_ body: Data?) -> Self {
    var `self` = self
    `self`.self.body = body
    return `self`
  }
  
  public func headers(_ headers: Headers?) -> Self {
    var `self` = self
    `self`.self.headers = headers
    return `self`
  }
  
  public init(baseURL: URL? = nil,
              networkPath: NetworkPath? = nil,
              method: Method = .get,
              headers: Headers? = nil,
              body: Data? = nil) {
    self.baseURL = baseURL
    self.networkPath = networkPath
    self.method = method
    self.headers = headers
    self.body = body
  }
}
