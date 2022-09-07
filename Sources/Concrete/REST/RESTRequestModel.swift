//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct RESTRequestModel: NetworkRequestModel {
  /// REST method, f.e. 'GET', 'POST'
  public enum Method: RawRepresentable {
    public var rawValue: String {
      switch self {
      case .get: return "GET"
      case .post: return "POST"
      case .custom(let method): return method
      }
    }
    
    public init(rawValue: String) {
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
  
  // MARK: - Public
  
  public var baseURL: URL?
  public var networkPath: NetworkPath?
  public var method: Method = .get
  public var headers: [String:String?]?
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
  
  public func headers(_ headers: [String: String?]?) -> Self {
    var `self` = self
    `self`.self.headers = headers
    return `self`
  }
}
