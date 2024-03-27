//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

final class JSONTransformer: BodyTransformer {
  let encoder = JSONEncoder()
  
  func map<T: Encodable>(_ object: T) throws -> Data? {
    return try self.encoder.encode(object)
  }
}
