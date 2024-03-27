//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

struct SocketRequest: NetworkRequest {
  // MARK: - NetworkRequest
  
  var request: (any Sendable)?
  var subscription: Bool = false
  var publisherId: String? = nil
  
  init(request: (any Sendable)?) {
    self.request = request
  }
}
