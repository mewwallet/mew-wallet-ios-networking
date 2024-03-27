@testable import mew_wallet_ios_networking

import os
import Foundation
import Testing
import mew_wallet_ios_logger

@Suite("WebSocketClient tests")
struct WebSocketClientTests {
  @Test("Test simple success")
  func succeed() async throws {
    await withThrowingTaskGroup(of: Void.self) { group in
      await withCheckedContinuation { continuation in
        group.addTask {
          let provider = NetworkProvider<EchoWS>(with: .with(URL(string: "wss://echo.websocket.org")!, headers: .empty.with(contentType: .applicationJSON)))
          let task: APITask<EchoBody> = try #require(try provider.call(.request))
          let response = try #require( try await task.execute() )
          #expect(response == EchoBody())
          
          let task2: APITask<EchoBody> = try #require(try provider.call(.request))
          let response2 = try #require( try await task2.execute() )
          #expect(response2 == EchoBody())
          
          // To check memory, that's totally optional
          try await Task.sleep(nanoseconds: 1_000_000_000)
          continuation.resume()
        }
      }
    }
  }
}
