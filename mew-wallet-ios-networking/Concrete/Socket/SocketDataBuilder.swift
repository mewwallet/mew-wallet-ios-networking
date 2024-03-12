import Foundation
import mew_wallet_ios_extensions

public protocol SocketDataBuilder: Sendable {
  func buildConnectionRequest(url: URL, headers: Headers) -> URLRequest
  func unwrap(request: any NetworkRequest) throws -> (IDWrapper, Data)
  func unwrap(data: Data) throws -> (IDWrapper, Data)
  // swiftlint:disable:next large_tuple
  func unwrap(response: String) throws -> (IDWrapper?, IDWrapper?, Data)
}

public final class SocketDataBuilderImpl: SocketDataBuilder {
  public let decoder = JSONDecoder()
  
  public init() {}

  public func buildConnectionRequest(url: URL, headers: Headers) -> URLRequest {
    var request = URLRequest(url: url)
    headers.forEach {
      request.addValue($0.value, forHTTPHeaderField: $0.key)
    }
    request.timeoutInterval = 15
    return request
  }
  
  public func unwrap(request: any NetworkRequest) throws -> (IDWrapper, Data) {
    if let data = request.request as? Data {
      return try self.unwrap(data: data)
    } else if let request = request.request as? URLRequest {
      guard let data = request.httpBody else {
        throw SocketClientError.badFormat
      }
      return try self.unwrap(data: data)
    }
    
    throw SocketClientError.badFormat
  }
  
  public func unwrap(data: Data) throws -> (IDWrapper, Data) {
    guard let id = try decoder.decode(_UnwrappedData.self, from: data).id else {
      throw SocketClientError.badFormat
    }
    return (id, data)
  }
  
  // swiftlint:disable:next large_tuple
  public func unwrap(response: String) throws -> (IDWrapper?, IDWrapper?, Data) {
    guard let data = response.data(using: .utf8) else {
      throw SocketClientError.badFormat
    }
    
    let unwrappedData = try decoder.decode(_UnwrappedData.self, from: data)
    return (unwrappedData.id, unwrappedData.subscriptionId, data)
  }
}

// MARK: - Request

private struct _UnwrappedData: Decodable {
  private enum CodingKeys: CodingKey {
    case id
    case result
    case params
  }
  private enum SubscriptionCodingKeys: CodingKey {
    case subscription
  }
  let id: IDWrapper?
  let subscriptionId: IDWrapper?
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(IDWrapper.self, forKey: .id)
    if let subscriptionId = try? container.decodeIfPresent(IDWrapper.self, forKey: .result) {
      self.subscriptionId = subscriptionId
    } else {
      guard let result = try? container.nestedContainer(keyedBy: SubscriptionCodingKeys.self, forKey: .params) else {
        self.subscriptionId = nil
        return
      }
      self.subscriptionId = try? result.decodeIfPresent(IDWrapper.self, forKey: .subscription)
    }
  }
}
