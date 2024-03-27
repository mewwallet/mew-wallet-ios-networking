@testable import mew_wallet_ios_networking_websocket

import os
import Foundation
import Testing
import mew_wallet_ios_logger

@Suite("WebSocket.Connectivity tests")
struct ConnectivityTests {
  enum Configuration {
    case singleCheck
    case infiniteDelay
    case shortDelay
    case tlsAutoPinnedShortDelay
    case tlsUnpinnedShortDelay
    case tlsBadPinnedShortDelay
    
    var configuration: WebSocket.Configuration {
      switch self {
      case .singleCheck:                return WebSocket.Configuration(tls: .disabled, reconnectDelay: nil, autoReplyPing: true, pingInterval: 10)
      case .infiniteDelay:              return WebSocket.Configuration(tls: .disabled, reconnectDelay: 100.0, autoReplyPing: true, pingInterval: 1000)
      case .shortDelay:                 return WebSocket.Configuration(tls: .disabled, reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .tlsAutoPinnedShortDelay:    return WebSocket.Configuration(tls: .pinned(domain: nil, allowSelfSigned: false), reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .tlsUnpinnedShortDelay:      return WebSocket.Configuration(tls: .unpinned, reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .tlsBadPinnedShortDelay:     return WebSocket.Configuration(tls: .pinned(domain: "websocket2.org", allowSelfSigned: false), reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      }
    }
  }
  
  init() {
//    Logger.System.connectivity.level(.trace)
  }
  
  @Test("Initial state", .tags(.general), arguments: [Configuration.singleCheck], [(URL(string: "ws://localhost:8085")!, UInt16(8085))])
  func initialState(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    #expect(connectivity.state == .idle)
  }
  
  @Test("Throws failed after single check", .tags(.general), arguments: [Configuration.singleCheck], [(URL(string: "ws://localhost:8086")!, UInt16(8086))])
  func throwsFailedAfterSingleCheck(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    #expect(connectivity.state == .idle)
    await #expect(throws: WebSocket.Connectivity.Error.failed) { try await connectivity.waitForConnectivity() }
    #expect(connectivity.state == .idle)
  }
  
  @Test("Throws cancelled", .tags(.general), arguments: [Configuration.infiniteDelay], [(URL(string: "ws://localhost:8087")!, UInt16(8087))])
  func throwsCancelled(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: WebSocket.Connectivity.Error.cancelled) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
      }
      
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        connectivity.cancel()
      }
    }
  }
  
  @Test("Throws invalid", .tags(.general), arguments: [Configuration.shortDelay], [(URL(string: "ws://localhost:8088")!, UInt16(8088))])
  func throwsInvalidOnDoubleWait(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        #expect(connectivity.state == .idle)
        await #expect(throws: WebSocket.Connectivity.Error.cancelled) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
      }
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(connectivity.state == .waiting)
        await #expect(throws: WebSocket.Connectivity.Error.invalid) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .waiting)
        connectivity.cancel()
      }
    }
  }
  
  @Test("Succeed connectivity after fail and retry", .tags(.general), arguments: [Configuration.shortDelay], [(URL(string: "ws://localhost:8089")!, UInt16(8089))])
  func succeedConnectivityAfterFailAndRetry(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    let server: MockWebSocketServer = try await MockWebSocketServer(port: endpoint.port)
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
        await server.shutdown()
      }
      group.addTask {
        try await Task.sleep(nanoseconds: 5_000_000_000) // wait 5 seconds
        try #require(try await server.run())
      }
    }
  }
  
  @Test("Succeed connectivity", .tags(.general), arguments: [Configuration.shortDelay], [(URL(string: "ws://localhost:8090")!, UInt16(8090))])
  func succeedConnectivity(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    let server: MockWebSocketServer = try await MockWebSocketServer(port: endpoint.port)
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000) // wait 3 seconds
        await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
        await server.shutdown()
      }
      group.addTask {
        try #require(try await server.run())
      }
    }
  }
  
  @Test("Cancel after restart", .tags(.general), arguments: [Configuration.shortDelay], [(URL(string: "ws://localhost:8091")!, UInt16(8091))])
  func cancelAfterRestart(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: WebSocket.Connectivity.Error.cancelled) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
        try await Task.sleep(nanoseconds: 2_000_000_000) // wait 2 seconds
        await #expect(throws: WebSocket.Connectivity.Error.cancelled) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
      }
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        connectivity.cancel()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        connectivity.cancel()
      }
    }
  }
  
  @Test("Succeed connectivity after server restart", .tags(.general), arguments: [Configuration.shortDelay], [(URL(string: "ws://localhost:8092")!, UInt16(8092))])
  func succeedConnectivityAfterServerRestart(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    let server: MockWebSocketServer = try await MockWebSocketServer(port: endpoint.port)
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
        await server.shutdown()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
        #expect(connectivity.state == .idle)
        await server.shutdown()
      }
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try #require(try await server.run())
        try await Task.sleep(nanoseconds: 3_000_000_000)
        try #require(try await server.run())
      }
    }
  }
  
  @Test("TLS", .tags(.general), .tags(.tls), arguments: [Configuration.shortDelay, .tlsAutoPinnedShortDelay, .tlsUnpinnedShortDelay, .tlsBadPinnedShortDelay], [(URL(string: "wss://echo.websocket.org")!, UInt16(0))])
  func tls(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let connectivity = try WebSocket.Connectivity(url: endpoint.url, configuration: configuration.configuration)
    
    switch configuration.configuration.tls {
    case .disabled:
      await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
    case .unpinned:
      await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
    case .pinned(let domain, _):
      if domain == "websocket2.org" {
        await #expect(throws: WebSocket.Connectivity.Error.tls) { try await connectivity.waitForConnectivity() }
      } else {
        await #expect(throws: Never.self) { try await connectivity.waitForConnectivity() }
      }
    }
    
    #expect(connectivity.state == .idle)
  }
}
