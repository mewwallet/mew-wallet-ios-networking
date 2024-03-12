//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

struct RESTRequest: NetworkRequest {
  // MARK: - NetworkRequest
  
  let request: (any Sendable)?
  
  init(request: (any Sendable)?) {
    self.request = request
  }
}
