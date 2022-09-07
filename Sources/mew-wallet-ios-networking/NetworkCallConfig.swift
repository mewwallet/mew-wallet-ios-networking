//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 7/10/22.
//

import Foundation

//struct NetworkCallConfig {
//  let requestModel: RequestModel
//}





//
//    if let headers = requestDataModel?.headerFields {
//      for header in headers {
//        urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
//      }
//    }
//
//    return .success(urlRequest)
//  }
//}
//
//extension URLComponents {
//  mutating func setQueryItems(with parameters: [String: String]) {
//    self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
//  }
//}

//
//struct CompoundOperationBuilderConfig {
//  // MARK: - General parameters
//  let inputData: Any?
//
//  // MARK: - Request configuration operation parameters
//  let requestConfigurationType: RequestConfiguratorType
//  let requestMethod: NetworkHTTPMethod
//  let requestService: String?
//  let requestURLParameters: [String]?
//  let requestSubscription: Bool
//
//  // MARK: - Request network client
//  let networkClientType: NetworkClientType
//
//  // MARK: - Response deserialization operation parameters
//  let responseDeserializationType: ResponseDeserializerType
//
//  // MARK: - Validation operation parameters
//  let responseValidationType: ResponseValidatorType
//
//  // MARK: - Response converting operation parameters
//  let responseConvertingType: ResponseConverterType
//
//  // MARK: - Mapping operation type
//  let responseMappingType: ResponseMapperType
//  let responseMappingContext: ResponseMappingContext?
//  let responseMappingType2: ResponseMapperType
//  let responseMappingContext2: ResponseMappingContext?
//
//  init(inputData: Any?,
//       requestConfigurationType: RequestConfiguratorType,
//       requestMethod: NetworkHTTPMethod,
//       requestService: String?,
//       requestURLParameters: [String]?,
//       requestSubscription: Bool,
//       networkClientType: NetworkClientType,
//       responseDeserializationType: ResponseDeserializerType,
//       responseValidationType: ResponseValidatorType,
//       responseConvertingType: ResponseConverterType,
//       responseMappingType: ResponseMapperType,
//       responseMappingContext: ResponseMappingContext?,
//       responseMappingType2: ResponseMapperType = .disabled,
//       responseMappingContext2: ResponseMappingContext? = nil) {
//    self.inputData                      = inputData
//    self.requestConfigurationType       = requestConfigurationType
//    self.requestMethod                  = requestMethod
//    self.requestService                 = requestService
//    self.requestURLParameters           = requestURLParameters
//    self.requestSubscription            = requestSubscription
//    self.networkClientType              = networkClientType
//    self.responseDeserializationType    = responseDeserializationType
//    self.responseValidationType         = responseValidationType
//    self.responseConvertingType         = responseConvertingType
//    self.responseMappingType            = responseMappingType
//    self.responseMappingContext         = responseMappingContext
//    self.responseMappingType2           = responseMappingType2
//    self.responseMappingContext2        = responseMappingContext2
//  }
//}
