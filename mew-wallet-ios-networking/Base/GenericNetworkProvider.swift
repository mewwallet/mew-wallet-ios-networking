//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 12/21/22.
//

import Foundation

public protocol GenericNetworkProvider: Sendable {
  func postProcess<R: Sendable>(task: APITask<R>, result: R) 
}
