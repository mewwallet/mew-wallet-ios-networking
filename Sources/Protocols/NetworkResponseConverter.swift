//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseConverter {
  func convert(_ data: Any) async throws -> Any?
}
