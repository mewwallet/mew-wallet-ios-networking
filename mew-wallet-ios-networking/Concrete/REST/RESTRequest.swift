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
  
  init(request: Any?) {
    self.request = request
  }
}
