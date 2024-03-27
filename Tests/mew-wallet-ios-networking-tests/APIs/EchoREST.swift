//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation
import mew_wallet_ios_networking

enum EchoREST: APINetworkPath {
  var isSocket: Bool { false }
  
  case getRequest
  case postRequest
  
  var method: RESTRequestModel.Method {
    switch self {
    case .getRequest:
      return .get
    case .postRequest:
      return .post
    }
  }
  
  var path: String {
    switch self {
    case .getRequest:
      return "get"
    case .postRequest:
      return "post"
    }
  }
  
  var query: [URLQueryItem]? {
    return nil
  }
  
  func body<API>(_ configuration: NetworkProvider<API>.Configuration) throws -> Data? {
    switch self {
    case .getRequest:
      return nil
    case .postRequest:
      return try configuration.bodyTransformer.map(EchoBody())
    }
  }
  
  var mapper: NetworkResponseMapper? {
    switch self {
    case .getRequest:
      return JSONMapper<EchoResponse>()
    case .postRequest:
      return JSONMapper<EchoResponse>()
    }
  }
  
  func task<API, R>(_ configuration: NetworkProvider<API>.Configuration, provider: any GenericNetworkProvider) throws -> APITask<R> where API : APINetworkPath {
    guard let baseURL = configuration.baseURL else { throw APINetworkPathError.badConfiguration }
    let networkClient = RESTClient(session: .shared)

    let request = RESTRequestModel(baseURL: baseURL,
                                   networkPath: self,
                                   method: self.method,
                                   headers: configuration.headers,
                                   body: try self.body(configuration))
    
    var config = NetworkRequestConfig(request: .rest(request),
                                      client: networkClient)

    // Mapping
    if let mapper = self.mapper {
      config = config.mapping(.custom(mapper))
    }
    return APITask<R>(path: self, provider: provider) {[config = config] in
      try await NetworkTask.run(config: config)
    }
  }
  
  func task<API, R>(_ configuration: NetworkProvider<API>.Configuration, socketClient: SocketNetworkClient, provider: any GenericNetworkProvider) throws -> mew_wallet_ios_networking.APITask<R> where API : APINetworkPath {
    throw APINetworkPathError.notImplemented
  }
  
  func taskDrySubscriptionResult<R>(from subscriptionId: String?, provider: any GenericNetworkProvider) throws -> APITask<R> where R : Sendable {
    throw APINetworkPathError.notImplemented
  }
  
  func taskSubscriptionId<R>(result: R) throws -> String? {
    throw APINetworkPathError.notImplemented
  }
}
