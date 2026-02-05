//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation

public final class JSONMapper<R: Decodable & Sendable, E: Decodable & Sendable>: NetworkResponseMapper {
  public let decoder = JSONDecoder()
  
  public init() {
  }
  
  public func map(responseCode: NetworkResponseCode, headers: Headers?, response: any Sendable) async throws -> (any Sendable)? {
    decoder.userInfo[.networkResponseCode] = responseCode
    guard let data = response as? Data else { throw MapperBase.Error.badInput }
    
    if E.self == Never.self || responseCode.isSuccess {
      return try decoder.decode(R.self, from: data)
    } else {
      return try decoder.decode(E.self, from: data)
    }
  }
}

// MARK: - Extensions

extension CodingUserInfoKey {
  public static let networkResponseCode = CodingUserInfoKey(rawValue: "_networkResponseCode")!
}
