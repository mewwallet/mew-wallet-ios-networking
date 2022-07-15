//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 7/10/22.
//

import Foundation

protocol NetworkResponseConverter {
  func convert(_ response: NetworkResponse) -> NetworkResponse
}
