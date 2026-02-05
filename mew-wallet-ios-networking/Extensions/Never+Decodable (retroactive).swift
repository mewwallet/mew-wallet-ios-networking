//
//  File.swift
//  mew-wallet-ios-networking
//
//  Created by Mikhail Nikanorov on 2/5/26.
//

import Foundation

@available(iOS, introduced: 13.0, obsoleted: 17.0)
@available(tvOS, introduced: 13.0, obsoleted: 17.0)
@available(watchOS, introduced: 6.0, obsoleted: 10.0)
@available(macOS, introduced: 10.15, obsoleted: 14.0)
extension Never: @retroactive Decodable {
  public init(from decoder: Decoder) throws {
    throw DecodingError.dataCorrupted(
      .init(codingPath: decoder.codingPath,
            debugDescription: "Attempted to decode Never (backport)")
    )
  }
}
