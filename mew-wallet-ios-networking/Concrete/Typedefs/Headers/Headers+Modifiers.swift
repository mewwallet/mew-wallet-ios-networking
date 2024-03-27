//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/9/24.
//

import Foundation

extension Headers {
  public func with(contentType: ContentType) -> Headers {
    return self.with(header: .contentType, value: contentType.rawValue)
  }
  
  public func with(accept: ContentType) -> Headers {
    return self.with(header: .accept, value: accept.rawValue)
  }
    
  public func with(userAgent: String) -> Headers {
    return self.with(header: .userAgent, value: userAgent)
  }
  
  public func with(origin: String) -> Headers {
    return self.with(header: .origin, value: origin)
  }
    
  public func with(header: Header, value: String) -> Headers {
    return self.with(key: header.rawValue, value: value)
  }
  
  public func merge(headers: Headers) -> Headers {
    var `self` = self
    `self`.merge(headers, uniquingKeysWith: { $1 })
    return `self`
  }

  public func with(key: String, value: String) -> Headers {
    var `self` = self
    `self`[key] = value
    return `self`
  }
}
