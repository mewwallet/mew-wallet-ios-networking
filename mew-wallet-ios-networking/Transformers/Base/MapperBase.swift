//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation

public final class MapperBase: NetworkResponseMapper {
  public enum Error: LocalizedError {
    case badInput
    
    public var errorDescription: String? {
      return "MapperBase: bad input"
    }
  }
  
  public typealias Context = @Sendable (Headers?, Data) async throws -> (any Sendable)?
  
  let context: Context
  
  public init(_ context: @escaping Context) {
    self.context = context
  }
  
  public func map(headers: Headers?, response: any Sendable) async throws -> (any Sendable)? {
    guard let data = response as? Data else { throw Error.badInput }
    return try await self.context(headers, data)
  }
}
