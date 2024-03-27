//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation

public final class JSONMapper<T: Decodable & Sendable>: NetworkResponseMapper {
  public let decoder = JSONDecoder()
  
  public init() {
  }  
  
  public func map(headers: Headers?, response: any Sendable) async throws -> (any Sendable)? {
    guard let data = response as? Data else { throw MapperBase.Error.badInput }
    return try decoder.decode(T.self, from: data)
  }
}
