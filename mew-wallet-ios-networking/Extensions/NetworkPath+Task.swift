//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 10/28/22.
//

import Foundation

public enum APINetworkPathError: LocalizedError {
  case badResponse
  case badConfiguration
  case notImplemented
}

public protocol APINetworkPath: NetworkPath {
  associatedtype API = NetworkProvider<Self>.APIPATH
  func task<API: Sendable, R: Sendable>(_ configuration: NetworkProvider<API>.Configuration, provider: any GenericNetworkProvider) throws -> APITask<R>
  func task<API: Sendable, R: Sendable>(_ configuration: NetworkProvider<API>.Configuration, socketClient: SocketNetworkClient, provider: any GenericNetworkProvider) throws -> APITask<R>
  func taskDrySubscriptionResult<R: Sendable>(from subscriptionId: String?, provider: any GenericNetworkProvider) throws -> APITask<R>
  func taskSubscriptionId<R: Sendable>(result: R) throws -> String?
}
