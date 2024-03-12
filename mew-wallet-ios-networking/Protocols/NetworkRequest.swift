//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public protocol NetworkRequest: Sendable {
  var request: (any Sendable)? { get }
  
  init(request: (any Sendable)?)
}
