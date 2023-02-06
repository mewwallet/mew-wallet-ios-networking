//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public enum NetworkResponseCode {
  case success                // 200
  case accepted               // 202
  case notFound               // 404
  case conflict               // 409
  case aws_tooManyRequests    // 429
  case unknown(Int)
  
  init?(rawValue: Int) {
    switch rawValue {
    case 200:   self = .success
    case 202:   self = .accepted
    case 404:   self = .notFound
    case 409:   self = .conflict
    case 429:   self = .aws_tooManyRequests
    default:    self = .unknown(rawValue)
    }
  }
  
  public var code: Int {
    switch self {
    case .success:              return 200
    case .accepted:             return 202
    case .notFound:             return 404
    case .conflict:             return 409
    case .aws_tooManyRequests:  return 429
    case .unknown(let code):    return code
    }
  }
  
  public var isSuccess: Bool {
    return (200..<300).contains(self.code) // 2xx codes
  }
}

public protocol NetworkResponse {
  var response: HTTPURLResponse? { get }
  var data: Any? { get }
  var statusCode: NetworkResponseCode { get }
  
  init(_ response: HTTPURLResponse?, data: Any?, statusCode: Int)
  init(_ response: HTTPURLResponse?, data: Any?, statusCode: NetworkResponseCode)
}
