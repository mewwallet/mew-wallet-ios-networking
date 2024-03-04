import XCTest
import Combine
import os
import mew_wallet_ios_logger
@testable import mew_wallet_ios_networking_websocket

final class mew_wallet_ios_networking_websocket_tests: XCTestCase {
//  var cancellables = Set<AnyCancellable>()
  
  var server: MockWebSocketServer!
//  var client: WebSocket!
  let shortDelayConfiguration       = WebSocket.Configuration(certificatePinning: false, reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
  let noPingShortDelayConfiguration = WebSocket.Configuration(certificatePinning: false, reconnectDelay: 1.0, autoReplyPing: false, pingInterval: 1.0)
  
  let url = URL(string: "ws://localhost:8085")!
  
  override class func setUp() {
    Logger.System.webSocket.level(.trace)
  }
  
  override func setUp() async throws {
    self.server = try MockWebSocketServer(port: 8085)
//    self.client = try WebSocket(url: url)
    
//    try self.server.run()
  }
  
  override func tearDownWithError() throws {
//    self.server.shutdown()
  }
  
  func testConnectThenDisconnect() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
        let client = try WebSocket(url: url, configuration: self.shortDelayConfiguration)
        group.addTask {
          XCTAssertEqual(client.state, .disconnected)
          let expectedSequience: [WebSocket.Event] = [
            .connectionError(.notReachable)
          ]
          var events: [WebSocket.Event] = []
          for await event in client.connect() {
            events.append(event)
          }
          XCTAssertEqual(expectedSequience, events)
          XCTAssertEqual(client.state, .disconnected)
        }
        
        group.addTask {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          client.disconnect()
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
  func testConnectionSequienceThenDisconnectServer() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let client = try WebSocket(url: url, configuration: self.shortDelayConfiguration)
        group.addTask {
          XCTAssertEqual(client.state, .disconnected)
          var hadPing = false
          var hadPong = false
          let expectedSequience: [WebSocket.Event] = [
            .connected,
            .viabilityDidChange(true),
            .text("Hello world"),
            .binary("Hello world".data(using: .utf8)!),
            .disconnected
          ]
          var events: [WebSocket.Event] = []
          // +ping-pong
          for await event in client.connect() {
            if event == .pong {
              hadPong = true
            } else if event == .ping {
              hadPing = true
            } else {
              events.append(event)
            }
          }
          XCTAssertTrue(hadPing)
          XCTAssertTrue(hadPong)
          XCTAssertEqual(expectedSequience, events)
          XCTAssertEqual(client.state, .disconnected)
        }
        
        group.addTask {
          do {
            try self.server.run()
            XCTAssertFalse(self.server.pingReceived)
            XCTAssertFalse(self.server.pongReceived)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.broadcast(message: "Hello world")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.broadcast(data: "Hello world".data(using: .utf8)!)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.shutdown()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            XCTAssertTrue(self.server.pingReceived)
            XCTAssertTrue(self.server.pongReceived)
            client.disconnect()
          } catch {
            XCTFail(error.localizedDescription)
          }
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
  func testNoPingConnectionSequienceThenDisconnectServer() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let client = try WebSocket(url: url, configuration: self.noPingShortDelayConfiguration)
        group.addTask {
          XCTAssertEqual(client.state, .disconnected)
          var hadPing = false
          var hadPong = false
          let expectedSequience: [WebSocket.Event] = [
            .connected,
            .viabilityDidChange(true),
            .text("Hello world"),
            .binary("Hello world".data(using: .utf8)!),
            .disconnected
          ]
          var events: [WebSocket.Event] = []
          // +ping-pong
          for await event in client.connect() {
            if event == .pong {
              hadPong = true
            } else if event == .ping {
              hadPing = true
              client.pong()
            } else {
              events.append(event)
            }
          }
          XCTAssertTrue(hadPing)
          XCTAssertTrue(hadPong)
          XCTAssertEqual(expectedSequience, events)
          XCTAssertEqual(client.state, .disconnected)
        }
        
        group.addTask {
          do {
            try self.server.run()
            XCTAssertFalse(self.server.pingReceived)
            XCTAssertFalse(self.server.pongReceived)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.broadcast(message: "Hello world")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.broadcast(data: "Hello world".data(using: .utf8)!)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            XCTAssertTrue(self.server.pingReceived)
            XCTAssertTrue(self.server.pongReceived)
            self.server.shutdown()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            client.disconnect()
          } catch {
            XCTFail(error.localizedDescription)
          }
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
  func testConnectionSequienceThenDisconnectClient() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let client = try WebSocket(url: url, configuration: self.shortDelayConfiguration)
        group.addTask {
          XCTAssertEqual(client.state, .disconnected)
          var hadPing = false
          var hadPong = false
          let expectedSequience: [WebSocket.Event] = [
            .connected,
            .viabilityDidChange(true),
            .text("Hello world"),
            .binary("Hello world".data(using: .utf8)!),
            .disconnected
          ]
          var events: [WebSocket.Event] = []
          // +ping-pong
          for await event in client.connect() {
            if event == .pong {
              hadPong = true
            } else if event == .ping {
              hadPing = true
            } else {
              events.append(event)
            }
          }
          XCTAssertTrue(hadPing)
          XCTAssertTrue(hadPong)
          XCTAssertEqual(expectedSequience, events)
          XCTAssertEqual(client.state, .disconnected)
        }
        
        group.addTask {
          do {
            try self.server.run()
            XCTAssertFalse(self.server.pingReceived)
            XCTAssertFalse(self.server.pongReceived)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.broadcast(message: "Hello world")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.server.broadcast(data: "Hello world".data(using: .utf8)!)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            client.disconnect()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            XCTAssertTrue(self.server.pingReceived)
            XCTAssertTrue(self.server.pongReceived)
            self.server.shutdown()
          } catch {
            XCTFail(error.localizedDescription)
          }
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
  func testConnectionSequienceForMultipleConsumers() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let client = try WebSocket(url: url, configuration: self.shortDelayConfiguration)
        
        group.addTask {
          do {
            XCTAssertFalse(self.server.pingReceived)
            XCTAssertFalse(self.server.pongReceived)
            try self.server.run()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.server.broadcast(message: "Hello world")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.server.broadcast(data: "Hello world".data(using: .utf8)!)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.server.broadcast(message: "Break client 2")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.server.broadcast(message: "Hello world 2")
            self.server.broadcast(data: "Hello world 2".data(using: .utf8)!)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            client.disconnect()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            XCTAssertTrue(self.server.pingReceived)
            XCTAssertTrue(self.server.pongReceived)
            self.server.shutdown()
          } catch {
            XCTFail(error.localizedDescription)
          }
        }
        
        await withCheckedContinuation { continuation in
          group.addTask {
            XCTAssertEqual(client.state, .disconnected)
            var hadPong = false
            var hadPing = false
            let expectedSequience: [WebSocket.Event] = [
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
            // +ping-pong
            for await event in client.connect() {
              if event == .viabilityDidChange(true) {
                continuation.resume()
              }
              if event == .pong {
                hadPong = true
              } else if event == .ping {
                hadPing = true
              } else {
                events.append(event)
              }
            }
            XCTAssertTrue(hadPing)
            XCTAssertTrue(hadPong)
            XCTAssertEqual(expectedSequience, events)
            XCTAssertEqual(client.state, .disconnected)
          }
        }
        
        group.addTask {
          XCTAssertEqual(client.state, .connected)
          var hadPing = false
          var hadPong = false
          let expectedSequience: [WebSocket.Event] = [
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
          XCTAssertTrue(hadPing)
          XCTAssertTrue(hadPong)
          XCTAssertEqual(expectedSequience, events)
          XCTAssertEqual(client.state, .connected)
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
  func testWSSEchoServer() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
        let client = try WebSocket(url: URL(string: "wss://echo.websocket.org")!, configuration: self.shortDelayConfiguration)
        
        await withCheckedContinuation { continuation in
          group.addTask {
            XCTAssertEqual(client.state, .disconnected)
            let expectedSequience: [WebSocket.Event] = [
              .connected,
              .viabilityDidChange(true),
              .text("Hello"),
              .binary("World".data(using: .utf8)!),
              .disconnected
            ]
            var events: [WebSocket.Event] = []
            // +ping-pong
            for await event in client.connect() {
              if event == .viabilityDidChange(true) {
                continuation.resume()
              }
              if case .text(let string) = event, (string ?? "").hasPrefix("Request") {
                continue
              }
              events.append(event)
            }
            XCTAssertEqual(expectedSequience, events)
            XCTAssertEqual(client.state, .disconnected)
          }
        }
        
        group.addTask {
          do {
            try await client.send("Hello")
            try await Task.sleep(nanoseconds: 300_000_000)
            try await client.send("World".data(using: .utf8)!)
            try await Task.sleep(nanoseconds: 300_000_000)
            client.disconnect()
          } catch {
            XCTFail(error.localizedDescription)
          }
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
  
  
  func atestWSSEchoServer22() async throws {
    await withTaskGroup(of: Void.self) { group in
      do {
//        let client = try WebSocket(url: URL(string: "wss://proportionate-dark-diagram.quiknode.pro/584139efc998d13f1e932a47f759283b6fc44de1/")!
        let client = try WebSocket(url: URL(string: "wss://nodesmw.mewapi.io:443/ws/eth")!, headers: [
          (name: "User-Agent", value: "MEWwallet"),
          (name: "Origin", value: "null")
        ])
        await withCheckedContinuation { continuation in
          let cont: CheckedContinuation<Void, Never>? = continuation
          group.addTask {[cont = cont] in
            var cont = cont
            XCTAssertEqual(client.state, .disconnected)
            let expectedSequience: [WebSocket.Event] = [
              .connected,
              .viabilityDidChange(true),
              .text("Hello"),
              .binary("World".data(using: .utf8)!),
              .disconnected
            ]
            var events: [WebSocket.Event] = []
            // +ping-pong
            for await event in client.connect() {
              if event == .viabilityDidChange(true) {
                cont?.resume()
                cont = nil
              }
              events.append(event)
              if case .text = event {
                break
              }
            }
            if let cont {
              cont.resume()
            }
            XCTAssertEqual(expectedSequience, events)
            XCTAssertEqual(client.state, .disconnected)
          }
        }
        
        group.addTask {
          do {
            // Result
            try await Task.sleep(nanoseconds: 5_000_000_000)
            
            try await client.send("{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", \"latest\"],\"id\":1}".data(using: .utf8)!)
//            try await client.send("World".data(using: .utf8)!)
//            try await Task.sleep(nanoseconds: 300_000_000)
//            client.disconnect()
          } catch {
            XCTFail(error.localizedDescription)
          }
        }
      } catch {
        XCTFail("Unexpected error")
      }
    }
  }
  
//  func testSuccessConnectivity() async throws {
//    await withTaskGroup(of: Void.self) { group in
//      group.addTask {
//        do {
//          let connectivity = WebSocket.Connectivity(url: self.url)
//          try await connectivity.waitForConnectivity()
//          
//          self.server.shutdown()
//        } catch {
//          XCTFail(error.localizedDescription)
//        }
//      }
//      group.addTask {
//        do {
//          try await Task.sleep(nanoseconds: 3_000_000_000) // wait 3 seconds
//          try self.server.run()
//        } catch {
//          XCTFail(error.localizedDescription)
//        }
//      }
//    }
//  }
//  
//  
//  func testSomething() async throws {
//    await withTaskGroup(of: Void.self) {[weak self] group in
//      group.addTask {[weak self] in
//        guard let self else { return }
////        try? self.server.run()
//        debugPrint("ok, created")
//        for await event in self.client.connect() {
//          debugPrint("!! EVENT: \(event)")
//        }
//        debugPrint("something")
//      }
//      
////      group.addTask {
////        for _ in 0..<100 {
////          try? await Task.sleep(nanoseconds: 1_000_000_000)
////          debugPrint("\(Date.now) ping")
////        }
////      }
//      
//      group.addTask {[weak self] in
//        try? await Task.sleep(nanoseconds: 100_000_000_000)
//        debugPrint("\(Date.now) >> STOP")
//        self?.client.disconnect()
//      }
//      
//      group.addTask {[weak self] in
//        try? await Task.sleep(nanoseconds: 5_000_000_000)
//        debugPrint("\(Date.now) >> Sent hello")
//        try? await self?.client.send("Hello")
//        try? self?.server.run()
//      }
//      
//      group.addTask {[weak self] in
//        try? await Task.sleep(nanoseconds: 10_000_000_000)
//        debugPrint("\(Date.now) >> Sent hello 2")
//        try? await self?.client.send("Hello")
//      }
//    }
//  }
    
//  func test() async {
//    let networkClient = RESTClient(session: .shared)
//    
//    let baseURL = URL(string: "https://mainnet.mewwallet.dev")!
//    let request = RESTRequestModel(baseURL: baseURL,
//                                   networkPath: TestMEWPath.v2_stake_info,
//                                   method: .get,
//                                   headers: nil,
//                                   body: nil)
//    
//    let config = NetworkRequestConfig(request: .rest(request),
//                                      client: networkClient,
//                                      deserialization: .disable,
//                                      validation: .disable,
//                                      conversion: .disable,
//                                      mapping: .disable)
//    do {
//      let result: Data = try await NetworkTask.shared.run(config: config)
//      debugPrint("Answer! \(String(data: result, encoding: .utf8) ?? "")")
//    } catch {
//      debugPrint("Error! \(error)")
//    }
//  }
}

//wss://proportionate-dark-diagram.quiknode.pro/584139efc998d13f1e932a47f759283b6fc44de1/


//

