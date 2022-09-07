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
  case unknown(Int)
  
  init?(rawValue: Int) {
    switch rawValue {
    case 200:   self = .success
    case 404:   self = .notFound
    default:    self = .unknown(rawValue)
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
