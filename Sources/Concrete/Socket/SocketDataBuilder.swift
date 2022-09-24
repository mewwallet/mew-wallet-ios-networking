import Foundation
import mew_wallet_ios_extensions

protocol SocketDataBuilder {
  func buildConnectionRequest(url: URL, headers: [String: String]) -> URLRequest
  func unwrap(request: NetworkRequest) throws -> (ValueWrapper, Data)
  func unwrap(data: Data) throws -> (ValueWrapper, Data)
  // swiftlint:disable:next large_tuple
  func unwrap(response: String) throws -> (ValueWrapper?, ValueWrapper?, Data)
}

final class SocketDataBuilderImpl: SocketDataBuilder {
  var decoder: JSONDecoder!

  func buildConnectionRequest(url: URL, headers: [String: String]) -> URLRequest {
    var request = URLRequest(url: url)
    headers.forEach {
      request.addValue($0.value, forHTTPHeaderField: $0.key)
    }
    return request
  }
  
  func unwrap(request: NetworkRequest) throws -> (ValueWrapper, Data) {
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
  
  func unwrap(data: Data) throws -> (ValueWrapper, Data) {
    guard let id = try decoder.decode(_UnwrappedData.self, from: data).id else {
      throw SocketClientError.badFormat
    }
    return (id, data)
  }
  
  // swiftlint:disable:next large_tuple
  func unwrap(response: String) throws -> (ValueWrapper?, ValueWrapper?, Data) {
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
  let id: ValueWrapper?
  let subscriptionId: ValueWrapper?
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(ValueWrapper.self, forKey: .id)
    if let subscriptionId = try? container.decodeIfPresent(ValueWrapper.self, forKey: .result) {
      self.subscriptionId = subscriptionId
    } else {
      guard let result = try? container.nestedContainer(keyedBy: SubscriptionCodingKeys.self, forKey: .params) else {
        self.subscriptionId = nil
        return
      }
      self.subscriptionId = try? result.decodeIfPresent(ValueWrapper.self, forKey: .subscription)
    }
  }
}
