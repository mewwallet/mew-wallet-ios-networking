//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol BodyTransformer: Sendable {
  func map<T: Encodable & Sendable>(_ object: T) throws -> Data?
}
