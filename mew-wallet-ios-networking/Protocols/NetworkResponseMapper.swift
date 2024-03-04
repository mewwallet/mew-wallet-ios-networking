//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseMapper {
  func map(_ response: Any) async throws -> Any?
}
