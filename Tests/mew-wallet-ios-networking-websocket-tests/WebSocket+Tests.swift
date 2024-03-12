@testable import mew_wallet_ios_networking_websocket

import os
import Foundation
import Network
import Testing
import mew_wallet_ios_logger

@Suite("WebSocket tests")
struct WebSocketTests {
  enum Configuration {
    case shortDelay
    case noPingShortDelay
    case tlsAutoPinnedShortDelay
    case tlsUnpinnedShortDelay
    case tlsBadPinnedShortDelay
    case tlsPinnedShortDelay
    
    var configuration: WebSocket.Configuration {
      switch self {
      case .shortDelay:                 return WebSocket.Configuration(tls: .disabled, reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .noPingShortDelay:           return WebSocket.Configuration(tls: .disabled, reconnectDelay: 1.0, autoReplyPing: false, pingInterval: 1.0)
        
      case .tlsAutoPinnedShortDelay:    return WebSocket.Configuration(tls: .pinned(domain: nil, allowSelfSigned: false), reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .tlsUnpinnedShortDelay:      return WebSocket.Configuration(tls: .unpinned, reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .tlsBadPinnedShortDelay:     return WebSocket.Configuration(tls: .pinned(domain: "websocket2.org", allowSelfSigned: false), reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      case .tlsPinnedShortDelay:        return WebSocket.Configuration(tls: .pinned(domain: "websocket.org", allowSelfSigned: false), reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
      }
    }
  }
  
  init() {
    //    Logger.System.connectivity.level(.trace)
  }
  
  @Test("Wait initial connect", .tags(.general), arguments: [Configuration.shortDelay], [(URL(string: "ws://localhost:8085")!, UInt16(8085))])
  func waitInitialConnect(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      let client = try #require(try WebSocket(url: endpoint.url, configuration: configuration.configuration))
      group.addTask {
        #expect(client.state == .disconnected)
        let expected: [WebSocket.Event] = []
        var events: [WebSocket.Event] = []
        for await event in client.connect() {
          events.append(event)
        }
        #expect(expected == events)
        #expect(client.state == .disconnected)
      }
      
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        client.disconnect()
      }
    }
  }
  
  @Test("Connection sequience then disconnect server", .tags(.general), arguments: zip([Configuration.shortDelay, .noPingShortDelay], [(URL(string: "ws://localhost:8086")!, UInt16(8086)), (URL(string: "ws://localhost:8087")!, UInt16(8087))]))
  func connectionSequienceThenDisconnectServer(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let server: MockWebSocketServer = try await MockWebSocketServer(port: endpoint.port)
    
    try await withThrowingTaskGroup(of: Void.self) { group in
      let client = try #require(try WebSocket(url: endpoint.url, configuration: configuration.configuration))
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(client.state == .disconnected)
        var hadPing = false
        var hadPong = false
        
        let expected: [WebSocket.Event] = [
          .connected,
          .viabilityDidChange(true),
          .text("Hello world"),
          .binary("Hello world".data(using: .utf8)!),
          .disconnected
        ]
        var events: [WebSocket.Event] = []
        for await event in client.connect() {
          if event == .pong {
            hadPong = true
          } else if event == .ping {
            hadPing = true
            if !configuration.configuration.autoReplyPing {
              client.pong()
            }
          } else {
            events.append(event)
          }
        }
        #expect(hadPing)
        #expect(hadPong)
        #expect(expected == events)
        #expect(client.state == .disconnected)
        await server.shutdown()
      }
      
      group.addTask {
        try #require(try await server.run())
        #expect(await server.pingReceived == false)
        #expect(await server.pongReceived == false)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await server.broadcast(message: "Hello world")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await server.broadcast(data: "Hello world".data(using: .utf8)!)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        #expect(await server.pingReceived == true)
        #expect(await server.pongReceived == true)
        await server.shutdown()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        client.disconnect()
      }
    }
  }
  
  @Test("Connection sequience then disconnect client", .tags(.general), arguments: zip([Configuration.shortDelay, .noPingShortDelay], [(URL(string: "ws://localhost:8088")!, UInt16(8088)), (URL(string: "ws://localhost:8089")!, UInt16(8089))]))
  func connectionSequienceThenDisconnectClient(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let server: MockWebSocketServer = try await MockWebSocketServer(port: endpoint.port)
    
    try await withThrowingTaskGroup(of: Void.self) { group in
      let client = try #require(try WebSocket(url: endpoint.url, configuration: configuration.configuration))
      group.addTask {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(client.state == .disconnected)
        var hadPing = false
        var hadPong = false
        
        let expected: [WebSocket.Event] = [
          .connected,
          .viabilityDidChange(true),
          .text("Hello world"),
          .binary("Hello world".data(using: .utf8)!),
          .disconnected
        ]
        var events: [WebSocket.Event] = []
        for await event in client.connect() {
          if event == .pong {
            hadPong = true
          } else if event == .ping {
            hadPing = true
            if !configuration.configuration.autoReplyPing {
              client.pong()
            }
          } else {
            events.append(event)
          }
        }
        #expect(hadPing)
        #expect(hadPong)
        #expect(expected == events)
        #expect(client.state == .disconnected)
        await server.shutdown()
      }
      
      group.addTask {
        try #require(try await server.run())
        #expect(await server.pingReceived == false)
        #expect(await server.pongReceived == false)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await server.broadcast(message: "Hello world")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await server.broadcast(data: "Hello world".data(using: .utf8)!)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        #expect(await server.pingReceived == true)
        #expect(await server.pongReceived == true)
        client.disconnect()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        await server.shutdown()
      }
    }
  }
  
  @Test("Multiple consumers", .tags(.general), arguments: zip([Configuration.shortDelay, .noPingShortDelay], [(URL(string: "ws://localhost:8090")!, UInt16(8090)), (URL(string: "ws://localhost:8091")!, UInt16(8091))]))
  func multipleConsumers(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    let server: MockWebSocketServer = try await MockWebSocketServer(port: endpoint.port)
    
    try await withThrowingTaskGroup(of: Void.self) { group in
      let client = try #require(try WebSocket(url: endpoint.url, configuration: configuration.configuration))
      
      group.addTask {
        try #require(try await server.run())
        #expect(await server.pingReceived == false)
        #expect(await server.pongReceived == false)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        await server.broadcast(message: "Hello world")
        try await Task.sleep(nanoseconds: 1_500_000_000)
        await server.broadcast(data: "Hello world".data(using: .utf8)!)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        await server.broadcast(message: "Break client 2")
        try await Task.sleep(nanoseconds: 1_500_000_000)
        await server.broadcast(message: "Hello world 2")
        await server.broadcast(data: "Hello world 2".data(using: .utf8)!)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        client.disconnect()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        #expect(await server.pingReceived == true)
        #expect(await server.pongReceived == true)
        await server.shutdown()
      }
      
      await withCheckedContinuation { continuation in
        group.addTask {
          #expect(client.state == .disconnected)
          var hadPong = false
          var hadPing = false
          
          let expected: [WebSocket.Event] = [
            .connected,
            .viabilityDidChange(true),
            .text("Hello world"),
            .binary("Hello world".data(using: .utf8)!),
            .text("Break client 2"),
            .text("Hello world 2"),
            .binary("Hello world 2".data(using: .utf8)!),
            .disconnected
          ]
          
          var events: [WebSocket.Event] = []
          for await event in client.connect() {
            if event == .viabilityDidChange(true) {
              continuation.resume()
            }
            if event == .pong {
              hadPong = true
            } else if event == .ping {
              hadPing = true
              if !configuration.configuration.autoReplyPing {
                client.pong()
              }
            } else {
              events.append(event)
            }
          }
          #expect(hadPing)
          #expect(hadPong)
          #expect(expected == events)
          #expect(client.state == .disconnected)
        }
      }
      
      group.addTask {
        #expect(client.state == .connected)
        var hadPing = false
        var hadPong = false
        let expected: [WebSocket.Event] = [
          .text("Hello world"),
          .binary("Hello world".data(using: .utf8)!),
        ]
        var events: [WebSocket.Event] = []
        // +ping-pong
        for await event in client.connect() {
          if event == .text("Break client 2") {
            break
          }
          if event == .pong {
            hadPong = true
          } else if event == .ping {
            hadPing = true
          } else {
            events.append(event)
          }
        }
        #expect(hadPing)
        #expect(hadPong)
        #expect(expected == events)
        #expect(client.state == .connected)
      }
    }
  }
  
  @Test("TLS", .timeLimit(.seconds(10)), .tags(.general), .tags(.tls), arguments: [Configuration.shortDelay, .tlsUnpinnedShortDelay, .tlsAutoPinnedShortDelay, .tlsUnpinnedShortDelay, .tlsBadPinnedShortDelay], [(URL(string: "wss://echo.websocket.org")!, UInt16(0))])
  func tls(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      let client = try #require(try WebSocket(url: endpoint.url, configuration: configuration.configuration))
      
      await withCheckedContinuation { continuation in
        group.addTask {
          #expect(client.state == .disconnected)
          let expected: [WebSocket.Event]
          switch configuration.configuration.tls {
          case .disabled: // Forced not secure connection
            expected = []
            continuation.resume() // Safe, because `.viabilityDidChange(true)` will never be called
          case .unpinned:
            expected = [
              .connected,
              .viabilityDidChange(true),
              .text("Hello"),
              .binary("World".data(using: .utf8)!),
              .disconnected
            ]
          case .pinned(let domain, _):
            if domain == "websocket2.org" {
              expected = [
                .error(NWError.tls(errSSLBadCert))
              ]
              continuation.resume() // Safe, because `.viabilityDidChange(true)` will never be called
            } else {
              expected = [
                .connected,
                .viabilityDidChange(true),
                .text("Hello"),
                .binary("World".data(using: .utf8)!),
                .disconnected
              ]
            }
          }
          
          var events: [WebSocket.Event] = []
          for await event in client.connect() {
            if event == .viabilityDidChange(true) {
              continuation.resume()
            }
            if case .text(let string) = event, (string ?? "").hasPrefix("Request") {
              continue
            }
            events.append(event)
          }
          #expect(expected == events)
          #expect(client.state == .disconnected)
        }
      }
      
      group.addTask {
        switch configuration.configuration.tls {
        case .disabled: // Forced not secure connection
          try await Task.sleep(nanoseconds: 2_000_000_000)
          client.disconnect()
        case .unpinned:
          try await client.send("Hello")
          try await Task.sleep(nanoseconds: 300_000_000)
          try await client.send("World".data(using: .utf8)!)
          try await Task.sleep(nanoseconds: 300_000_000)
          client.disconnect()
        case .pinned(let domain, _):
          if domain == "websocket2.org" {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            client.disconnect()
          } else {
            try await client.send("Hello")
            try await Task.sleep(nanoseconds: 500_000_000)
            try await client.send("World".data(using: .utf8)!)
            try await Task.sleep(nanoseconds: 500_000_000)
            client.disconnect()
          }
        }
      }
    }
  }
  
//  @Test("Ыщьу", .timeLimit(.seconds(10)), .tags(.general), .tags(.tls), arguments: [Configuration.tlsAutoPinnedShortDelay], [(URL(string: "wss://nodesmw.mewapi.io:443/ws/eth")!, UInt16(0))])
//  func someasd(configuration: Configuration, _ endpoint: (url: URL, port: UInt16)) async throws {
//    try await withThrowingTaskGroup(of: Void.self) { group in
//      let client = try #require(try WebSocket(url: endpoint.url, headers: [
//        (name: "User-Agent", value: "MEWwallet"),
//        (name: "Origin", value: "null")
//      ], configuration: configuration.configuration))
//      
//      
//      group.addTask {
//        #expect(client.state == .disconnected)
//        let expected: [WebSocket.Event] = []
//        
//        var events: [WebSocket.Event] = []
//        for await event in client.connect() {
//          events.append(event)
//        }
//        #expect(expected == events)
//        #expect(client.state == .disconnected)
//      }
//      
//      group.addTask {
//        try await Task.sleep(nanoseconds: 3_000_000_000)
//        try await client.send("{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", \"latest\"],\"id\":1}".data(using: .utf8)!)
//        try await Task.sleep(nanoseconds: 3_000_000_000)
//        client.disconnect()
//      }
//    }
//  }
}
