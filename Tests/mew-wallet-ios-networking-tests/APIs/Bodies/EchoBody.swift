//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation

struct EchoBody: Codable, Equatable {
  let id: String
  let message: String
  
  init(id: String = "ID", message: String = "Hello world") {
    self.id = id
    self.message = message
  }
}
