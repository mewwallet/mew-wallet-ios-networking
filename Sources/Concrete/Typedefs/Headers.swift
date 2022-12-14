//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 10/28/22.
//

import Foundation

public typealias Headers = Dictionary<String, String>

extension Headers {
  public enum ContentType: String {
    case applicationJSON = "application/json"
  }
  
  public static var empty = Headers()
  
  public func with(contentType: ContentType) -> Headers {
    var `self` = self
    `self`["Content-Type"] = contentType.rawValue
    return `self`
  }
  
  public func with(userAgent: String) -> Headers {
    var `self` = self
    `self`["User-Agent"] = userAgent
    return `self`
  }
  
  public func with(origin: String) -> Headers {
    var `self` = self
    `self`["Origin"] = origin
    return `self`
  }
  
  public func with(key: String, value: String) -> Headers {
    var `self` = self
    `self`[key] = value
    return `self`
  }
}
