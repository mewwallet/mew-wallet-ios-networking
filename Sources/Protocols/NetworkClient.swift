//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public protocol NetworkClient {
  func send(request: NetworkRequest) async throws -> NetworkResponse
}
