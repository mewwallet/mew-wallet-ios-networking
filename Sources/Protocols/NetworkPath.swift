//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public protocol NetworkPath {
  var isSocket: Bool { get }
  var path: String { get }
  var query: [URLQueryItem]? { get throws }
}
