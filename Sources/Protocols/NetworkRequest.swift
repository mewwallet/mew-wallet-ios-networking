//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public protocol NetworkRequest {
  var request: Any? { get }
  var publisherId: String? { get set }
  var subscription: Bool { get set }
  
  init(request: Any?)
}
