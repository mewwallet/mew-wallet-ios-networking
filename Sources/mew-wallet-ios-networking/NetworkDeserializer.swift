//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 7/10/22.
//

import Foundation

protocol ResponseDeserializer {
  func deserialize<T: Decodable>(_ data: NetworkResponse?) async throws -> T
}

final class JSONDeserializer: ResponseDeserializer {
  enum JSONDeserializerError: Error {
    case incorrectModel
    case emptyData
  }
  let decoder: JSONDecoder
  
  init(decoder: JSONDecoder) {
    self.decoder = decoder
  }
  
  func deserialize<T: Decodable>(_ data: NetworkResponse?) async throws -> T {
    guard let data = data?.data as? Data else { throw JSONDeserializerError.emptyData }
    
    return try self.decoder.decode(T.self, from: data)
  }
}
