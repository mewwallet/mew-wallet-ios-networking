//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct NetworkRequestConfig {
  public enum Request {
    case rest(NetworkRequestModel)
    case socket(NetworkRequestModel)
    
    var model: NetworkRequestModel {
      switch self {
      case .rest(let model):    return model
      case .socket(let model):  return model
      }
    }
  }
  
  public enum Deserialization {
    case disable
    case custom(NetworkResponseDeserializer)
  }
  
  public enum Validation {
    case disable
    case custom(NetworkResponseValidator)
  }
  
  public enum Conversion {
    case disable
    case custom(NetworkResponseConverter)
  }
  
  public enum Mapping {
    case disable
    case custom(NetworkResponseMapper)
  }
  
  let request: Request
  let client: NetworkClient
  let deserialization: Deserialization
  let validation: Validation
  let conversion: Conversion
  let mapping: Mapping
  
  // Build request ->
  // execute request ->
  // deserialize response? ->
  // validate response? ->
  // convert response?
  // map response ->
  // return response
}
