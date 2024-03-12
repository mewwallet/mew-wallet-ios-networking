//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation
import mew_wallet_ios_networking

enum EchoWS: APINetworkPath {
  var isSocket: Bool { true }
  
  case request
  case subRequest
  
  var path: String {
    return ""
  }
  
  var query: [URLQueryItem]? {
    return nil
  }
  
  func body<API>(_ configuration: NetworkProvider<API>.Configuration) throws -> Data? {
    switch self {
    case .request:
      return try configuration.bodyTransformer.map(EchoBody())
    case .subRequest:
      return Data()
    }
  }
  
  var mapper: NetworkResponseMapper? {
    switch self {
    case .request:
      return JSONMapper<EchoBody>()
    case .subRequest:
      return JSONMapper<EchoBody>()
    }
  }
  
  private var subscription: Bool {
    return self == .subRequest
  }
  
  private var publisherId: String? {
    switch self {
    case .subRequest: return "SUB"
    default:          return nil
    }
  }
  
  func task<API, R>(_ configuration: NetworkProvider<API>.Configuration, socketClient: SocketNetworkClient, provider: any GenericNetworkProvider) throws -> mew_wallet_ios_networking.APITask<R> where API : APINetworkPath {
    var request = SocketRequestModel(
      subscription: subscription,
      body: try self.body(configuration)
    )
    
    request.publisherId = publisherId
    
    var config = NetworkRequestConfig(
      request: .socket(request),
      client: socketClient
    )

    // Mapping
    if let mapper = mapper {
      config = config.mapping(.custom(mapper))
    }

    return APITask<R>(path: self, provider: provider) {[config = config] in
      try await NetworkTask.run(config: config)
    }
  }
  
  func task<API, R>(_ configuration: NetworkProvider<API>.Configuration, provider: any GenericNetworkProvider) throws -> APITask<R> where API : APINetworkPath {
    throw APINetworkPathError.notImplemented
  }
  
  func taskDrySubscriptionResult<R>(from subscriptionId: String?, provider: any GenericNetworkProvider) throws -> APITask<R> where R : Sendable {
    throw APINetworkPathError.notImplemented
//    guard case .newHeadsSubscriptionId(let payload) = self else {
//      throw Error.badMethod
//    }
//    guard let subscriptionId = subscriptionId else {
//      throw SocketClientError.badFormat
//    }
//    let dataUnwrapper = SocketDataBuilderImpl()
//    let (id, _) = try dataUnwrapper.unwrap(data: payload)
//    let response = JSONRPC.Response<String>(id: id.stringValue ?? String(id.intValue ?? 0), result: subscriptionId)
//    let encoder = JSONEncoder()
//    return APITask<R>(path: self) {
//      try encoder.encode(response) as! R
//    }
  }
  
  func taskSubscriptionId<R>(result: R) throws -> String? {
    throw APINetworkPathError.notImplemented
  }
}
