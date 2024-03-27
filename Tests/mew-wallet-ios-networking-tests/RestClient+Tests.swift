@testable import mew_wallet_ios_networking

import os
import Foundation
import Testing
import mew_wallet_ios_logger

@Suite("RestClient tests")
struct RestClientTests {
  enum Provider {
    case echo
    case invalid
    
    var provider: NetworkProvider<EchoREST> {
      switch self {
      case .echo:     NetworkProvider<EchoREST>(with: .with(URL(string: "https://postman-echo.com")!, headers: .empty.with(contentType: .applicationJSON)))
      case .invalid:  NetworkProvider<EchoREST>(with: .with(URL(string: "https://postman-echo2.com")!, headers: .empty.with(contentType: .applicationJSON)))
      }
    }
  }
  
  @Test("Test success .getRequest", arguments: [Provider.echo])
  func succeedGET(_ provider: Provider) async throws {
    let task: APITask<EchoResponse> = try #require(try provider.provider.call(.getRequest))
    let response = try #require( try await task.execute() )
    #expect(response.url == "https://postman-echo.com/\(EchoREST.getRequest.path)")
  }
  
  @Test("Test failed .getRequest", arguments: [Provider.invalid])
  func failedGET(_ provider: Provider) async throws {
    let task: APITask<EchoResponse> = try #require(try provider.provider.call(.getRequest))
    await #expect(throws: URLError.self) { try await task.execute() }
  }
  
  @Test("Test success .postRequest", arguments: [Provider.echo])
  func succeedPOST(_ provider: Provider) async throws {
    let task: APITask<EchoResponse> = try #require(try provider.provider.call(.postRequest))
    let response = try #require( try await task.execute() )
    #expect(response.url == "https://postman-echo.com/\(EchoREST.postRequest.path)")
    #expect(response.json == EchoBody())
  }
  
  @Test("Test failed .getRequest", arguments: [Provider.invalid])
  func failedPOST(_ provider: Provider) async throws {
    let task: APITask<EchoResponse> = try #require(try provider.provider.call(.postRequest))
    await #expect(throws: URLError.self) { try await task.execute() }
  }
}
