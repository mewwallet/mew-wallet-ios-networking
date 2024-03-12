//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/7/22.
//

import Foundation

public protocol NetworkResponseValidator: Sendable {
  func validate(_ response: any Sendable) async throws
}
