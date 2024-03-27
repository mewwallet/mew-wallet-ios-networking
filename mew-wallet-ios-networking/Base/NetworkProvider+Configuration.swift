//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/6/24.
//

import Foundation
import mew_wallet_ios_extensions

extension NetworkProvider {
  public final class Configuration: Sendable {
    
    private let _baseURL = ThreadSafe<URL?>(nil)
    public var baseURL: URL? { _baseURL.value }
    
    private let _headers = ThreadSafe<Headers>([:])
    public var headers: Headers { _headers.value }
    
    private let _bodyTransformer = ThreadSafe<any BodyTransformer>(JSONTransformer())
    public var bodyTransformer: any BodyTransformer { _bodyTransformer.value }
    
    // MARK: - Configuration
    
    public func baseURL(_ url: URL) {
      self._baseURL.value = url
    }
    
    public func headers(_ headers: Headers) {
      self._headers.value = headers
    }
    
    public func bodyTransformer(_ transformer: any BodyTransformer) {
      self._bodyTransformer.value = transformer
    }
    
    public static func with(_ baseURL: URL? = nil, headers: Headers = .empty) -> Configuration {
      let configuration = Configuration()
      if let baseURL = baseURL {
        configuration.baseURL(baseURL)
      }
      
      configuration.headers(headers)
      return configuration
    }
  }
}
