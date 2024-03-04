//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public protocol NetworkRequest {
  var request: Any? { get }
  
  init(request: Any?)
}
