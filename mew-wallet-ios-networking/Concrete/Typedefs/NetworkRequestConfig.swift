//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/6/22.
//

import Foundation

public struct NetworkRequestConfig: Sendable {
  public enum Request: Sendable {
    case rest(NetworkRequestModel)
    case socket(NetworkRequestModel)
    
    var model: NetworkRequestModel {
      switch self {
      case .rest(let model):    return model
      case .socket(let model):  return model
      }
    }
  }
  
  public enum Deserialization: Sendable {
    case disable
    case custom(NetworkResponseDeserializer)
  }
  
  public enum Validation: Sendable {
    case disable
    case custom(NetworkResponseValidator)
  }
  
  public enum Conversion: Sendable {
    case disable
    case custom(NetworkResponseConverter)
  }
  
  public enum Mapping: Sendable {
    case disable
    case custom(NetworkResponseMapper)
  }
  
  var request: Request
  var client: NetworkClient
  var deserialization: Deserialization
  var validation: Validation
  var conversion: Conversion
  var mapping: Mapping
  
  // MARK: - Init
  
  public init(request: Request,
              client: NetworkClient,
              deserialization: Deserialization = .disable,
              validation: Validation = .disable,
              conversion: Conversion = .disable,
              mapping: Mapping = .disable) {
    self.request = request
    self.client = client
    self.deserialization = deserialization
    self.validation = validation
    self.conversion = conversion
    self.mapping = mapping
  }
  
  // MARK: - Modifiers
  
  public func request(_ request: Request) -> Self {
    var `self` = self
    `self`.request = request
    return `self`
  }
  
  public func client(_ client: NetworkClient) -> Self {
    var `self` = self
    `self`.client = client
    return `self`
  }
  
  public func deserialization(_ deserialization: Deserialization) -> Self {
    var `self` = self
    `self`.deserialization = deserialization
    return `self`
  }
  
  public func validation(_ validation: Validation) -> Self {
    var `self` = self
    `self`.validation = validation
    return `self`
  }
  
  public func conversion(_ conversion: Conversion) -> Self {
    var `self` = self
    `self`.conversion = conversion
    return `self`
  }
  
  public func mapping(_ mapping: Mapping) -> Self {
    var `self` = self
    `self`.mapping = mapping
    return `self`
  }
}
