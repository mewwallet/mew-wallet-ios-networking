//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

struct RESTResponse: NetworkResponse {
  var response: HTTPURLResponse?
  var data: (any Sendable)?
  var statusCode: NetworkResponseCode
  
  init(_ response: HTTPURLResponse?, data: (any Sendable)?, statusCode: Int) {
    self.init(response, data: data, statusCode: .init(rawValue: statusCode) ?? .unknown(statusCode))
  }
  
  init(_ response: HTTPURLResponse?, data: (any Sendable)?, statusCode: NetworkResponseCode) {
    self.response = response
    self.data = data
    self.statusCode = statusCode
  }
}
