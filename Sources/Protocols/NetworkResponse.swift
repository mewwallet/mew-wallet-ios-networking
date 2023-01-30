//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public enum NetworkResponseCode {
  case success
  case notFound
  case aws_tooManyRequests
  case unknown(Int)
  
  init?(rawValue: Int) {
    switch rawValue {
    case 200:   self = .success
    case 404:   self = .notFound
    case 429:   self = .aws_tooManyRequests
    default:    self = .unknown(rawValue)
    }
  }
  
  public var code: Int {
    switch self {
    case .success:              return 200
    case .notFound:             return 404
    case .aws_tooManyRequests:  return 429
    case .unknown(let code):    return code
    }
  }
}

public protocol NetworkResponse {
  var response: HTTPURLResponse? { get }
  var data: Any? { get }
  var statusCode: NetworkResponseCode { get }
  
  init(_ response: HTTPURLResponse?, data: Any?, statusCode: Int)
  init(_ response: HTTPURLResponse?, data: Any?, statusCode: NetworkResponseCode)
}
