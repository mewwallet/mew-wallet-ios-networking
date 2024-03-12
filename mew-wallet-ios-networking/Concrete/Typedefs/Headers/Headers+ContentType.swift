//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/9/24.
//

import Foundation

extension Headers {
  public enum ContentType: String, Sendable {
    case applicationJSON = "application/json"
    case protobuf = "application/x-protobuf"
  }
}
