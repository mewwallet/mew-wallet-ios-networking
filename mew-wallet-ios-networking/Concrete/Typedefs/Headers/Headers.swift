//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 10/28/22.
//

import Foundation

public typealias Headers = Dictionary<String, String>

extension Headers {
  public static var empty: Headers { Headers() }
}
