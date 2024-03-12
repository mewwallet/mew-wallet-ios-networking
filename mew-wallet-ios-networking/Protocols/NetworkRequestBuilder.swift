//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

protocol NetworkRequestBuilder: Sendable {
  func build(with config: NetworkRequestModel) async throws -> any NetworkRequest
}
