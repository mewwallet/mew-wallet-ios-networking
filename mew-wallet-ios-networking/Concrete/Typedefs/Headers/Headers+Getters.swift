//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/9/24.
//

import Foundation

extension Headers {
  public enum ValueError: LocalizedError, Sendable {
    case notFound
    case badType
  }
  public func value<T: Sendable>(for header: Header) throws -> T {
    let header = header.rawValue.lowercased()
    guard let value = self.first(where: { $0.key.lowercased() == header })?.value else { throw ValueError.notFound }
    guard let typed = value as? T else { throw ValueError.badType }
    return typed
  }
  
  public func base64(for header: Header) throws -> Data {
    let base64: String = try self.value(for: header)
    guard let data = Data(base64Encoded: base64) else { throw ValueError.badType }
    return data
  }
}
