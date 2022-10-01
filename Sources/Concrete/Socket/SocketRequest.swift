//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

// newHeads provide in socket request to check if there is an active subscription

struct SocketRequest: NetworkRequest {
  // MARK: - NetworkRequest
  
  var request: Any?
  var subscription: Bool = false
  
  init(request: Any?) {
    self.request = request
  }
}
