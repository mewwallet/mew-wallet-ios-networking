//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/9/24.
//

import Foundation

extension Headers {
  var array: [(name: String, value: String)] {
    return self.reduce([(name: String, value: String)](), { partialResult, element in
      var partialResult = partialResult
      partialResult.append((name: element.key, value: element.value))
      return partialResult
    })
  }
}
