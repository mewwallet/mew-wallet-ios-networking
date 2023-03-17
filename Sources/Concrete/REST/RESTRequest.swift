//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

struct RESTRequest: NetworkRequest {
  // MARK: - NetworkRequest
  
  var request: Any?
  var subscription: Bool = false
  var publisherId: String? = nil

  init(request: Any?) {
    self.request = request
  }
}
