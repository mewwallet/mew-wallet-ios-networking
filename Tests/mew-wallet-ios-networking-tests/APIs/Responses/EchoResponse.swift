//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation

struct EchoResponse: Codable {
  let url: String
  let json: EchoBody?
}
