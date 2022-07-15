//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 7/10/22.
//

import Foundation

protocol NetworkResponseValidator {
  func validate(_ response: NetworkResponse) async throws
}
