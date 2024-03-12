//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/9/24.
//

import Foundation

extension Headers {
  public enum Header: Sendable {
    case contentType
    case accept
    case userAgent
    case origin
    case custom(String)
    
    public var rawValue: String {
      switch self {
      case .contentType:          return "Content-Type"
      case .accept:               return "Accept"
      case .userAgent:            return "User-Agent"
      case .origin:               return "Origin"
      case .custom(let raw):      return raw
      }
    }
  }
}
