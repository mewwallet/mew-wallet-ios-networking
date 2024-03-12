//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public enum NetworkResponseCode: Sendable {
  case success                // 200
  case accepted               // 202
  case badRequest             // 400
  case forbidden              // 403
  case notFound               // 404
  case notAcceptable          // 406
  case conflict               // 409
  case failedDependency       // 424
  case upgradeRequired        // 426
  case aws_tooManyRequests    // 429
  case unknown(Int)
  
  init?(rawValue: Int) {
    switch rawValue {
    case 200:   self = .success
    case 202:   self = .accepted
    case 400:   self = .badRequest
    case 403:   self = .forbidden
    case 404:   self = .notFound
    case 406:   self = .notAcceptable
    case 409:   self = .conflict
    case 424:   self = .failedDependency
    case 426:   self = .upgradeRequired
    case 429:   self = .aws_tooManyRequests
    default:    self = .unknown(rawValue)
    }
  }
  
  public var code: Int {
    switch self {
    case .success:              return 200
    case .accepted:             return 202
    case .badRequest:           return 400
    case .forbidden:            return 403
    case .notFound:             return 404
    case .notAcceptable:        return 406
    case .conflict:             return 409
    case .failedDependency:     return 424
    case .upgradeRequired:      return 426
    case .aws_tooManyRequests:  return 429
    case .unknown(let code):    return code
    }
  }
  
  public var isSuccess: Bool {
    return (200..<300).contains(self.code) // 2xx codes
  }
}

public protocol NetworkResponse: Sendable {
  var response: HTTPURLResponse? { get }
  var data: (any Sendable)? { get }
  var statusCode: NetworkResponseCode { get }
  
  init(_ response: HTTPURLResponse?, data: (any Sendable)?, statusCode: Int)
  init(_ response: HTTPURLResponse?, data: (any Sendable)?, statusCode: NetworkResponseCode)
}
