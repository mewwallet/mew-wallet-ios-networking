//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 12/12/22.
//

import Foundation

extension NetworkProvider: Equatable {
  public static func == (lhs: NetworkProvider<API>, rhs: NetworkProvider<API>) -> Bool {
    return lhs.uuid == rhs.uuid
  }
}
