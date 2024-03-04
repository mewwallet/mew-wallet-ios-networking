import XCTest
import Combine
import os
import mew_wallet_ios_logger
@testable import mew_wallet_ios_networking_websocket

final class mew_wallet_ios_networking_websocket_connectivity_tests: XCTestCase {
  var server: MockWebSocketServer!
  
  let singleCheckConfiguration    = WebSocket.Configuration(certificatePinning: false, reconnectDelay: nil, autoReplyPing: true, pingInterval: 10)
  let infiniteDelayConfiguration  = WebSocket.Configuration(certificatePinning: false, reconnectDelay: 100.0, autoReplyPing: true, pingInterval: 1000)
  let shortDelayConfiguration     = WebSocket.Configuration(certificatePinning: false, reconnectDelay: 1.0, autoReplyPing: true, pingInterval: 1.0)
  let url = URL(string: "ws://localhost:8085")!
  
  override class func setUp() {
    Logger.System.connectivity.level(.trace)
  }
  
  override func setUp() async throws {
    self.server = try MockWebSocketServer(port: 8085)
  }
  
  override func tearDown() {
    self.server.shutdown()    
  }
  
  func testStateSetup() async throws {
    let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.singleCheckConfiguration)
    XCTAssertEqual(connectivity.state, .idle)
  }
  
  func testFailedError() async throws {
    let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.singleCheckConfiguration)
    do {
      XCTAssertEqual(connectivity.state, .idle)
      try await connectivity.waitForConnectivity()
    } catch let error as WebSocket.Connectivity.Error {
      XCTAssertEqual(error, WebSocket.Connectivity.Error.failed)
      XCTAssertEqual(connectivity.state, .idle)
    } catch {
      XCTFail("Unexpected error")
    }
  }
  
  func testCancelledError() async throws {
    // Test '.cancelled' error on cancel
    let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.infiniteDelayConfiguration)
    await withTaskGroup(of: Void.self) {[connectivity = connectivity] group in
      group.addTask {
        do {
          try await connectivity.waitForConnectivity()
        } catch let error as WebSocket.Connectivity.Error {
          XCTAssertEqual(error, WebSocket.Connectivity.Error.cancelled)
          XCTAssertEqual(connectivity.state, .idle)
        } catch {
          XCTFail("Unexpected error")
        }
      }
      
      group.addTask {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        connectivity.cancel()
      }
    }
  }

  func testSuccessConnectivityAfterFailWithRestart() async throws {
    // Test '.cancelled' error on cancel
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        do {
          let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.shortDelayConfiguration)
          try await connectivity.waitForConnectivity()
          XCTAssertEqual(connectivity.state, .idle)
          self.server.shutdown()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: 5_000_000_000) // wait 3 seconds
          try self.server.run()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
    }
  }
  
  func testSuccessConnectivity() async throws {
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: 3_000_000_000) // wait 3 seconds
          let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.shortDelayConfiguration)
          try await connectivity.waitForConnectivity()
          XCTAssertEqual(connectivity.state, .idle)
          self.server.shutdown()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
      group.addTask {
        do {
          try self.server.run()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
    }
  }
  
  func testCancelRestart() async throws {
    // Test '.cancelled' error on cancel
    // Connectivity - run and failed, waiting for restart
    // Then - cancel
    // Restart connectivity - run and failed
    // Then - cancel again
    let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.shortDelayConfiguration)
    await withTaskGroup(of: Void.self) {[connectivity = connectivity] group in
      group.addTask {
        do {
          try await connectivity.waitForConnectivity()
        } catch let error as WebSocket.Connectivity.Error {
          XCTAssertEqual(error, WebSocket.Connectivity.Error.cancelled)
          XCTAssertEqual(connectivity.state, .idle)
        } catch {
          XCTFail("Unexpected error")
        }
        do {
          try await Task.sleep(nanoseconds: 2_000_000_000)
          try await connectivity.waitForConnectivity()
        } catch let error as WebSocket.Connectivity.Error {
          XCTAssertEqual(error, WebSocket.Connectivity.Error.cancelled)
          XCTAssertEqual(connectivity.state, .idle)
        } catch {
          XCTFail("Unexpected error")
        }
      }
      
      group.addTask {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        connectivity.cancel()
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        connectivity.cancel()
      }
    }
  }
  
  func testRestartConnectivity() async throws {
    let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.shortDelayConfiguration)
    // Test:
    // Connectivity - up and failed
    // Server - up -> connectivity success
    // Server - down -> connectivity up and failed
    // Server - up -> connectivity success
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        do {
          XCTAssertEqual(connectivity.state, .idle)
          try await connectivity.waitForConnectivity()
          XCTAssertEqual(connectivity.state, .idle)
          self.server.shutdown()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: 4_000_000_000) // wait 4 seconds
          XCTAssertEqual(connectivity.state, .idle)
          try await connectivity.waitForConnectivity()
          XCTAssertEqual(connectivity.state, .idle)
          self.server.shutdown()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: 3_000_000_000) // wait 3 seconds
          try self.server.run()
          try await Task.sleep(nanoseconds: 5_000_000_000) // wait another 5 seconds
          try self.server.run()
        } catch {
          XCTFail(error.localizedDescription)
        }
      }
    }
  }
  
  func testDoubleWait() async throws {
    // Test '.invalid' error on double wait
    let connectivity = WebSocket.Connectivity(url: self.url, configuration: self.shortDelayConfiguration)
    await withTaskGroup(of: Void.self) {[connectivity = connectivity] group in
      group.addTask {
        do {
          XCTAssertEqual(connectivity.state, .idle)
          try await connectivity.waitForConnectivity()
        } catch let error as WebSocket.Connectivity.Error {
          XCTAssertEqual(error, WebSocket.Connectivity.Error.cancelled)
          XCTAssertEqual(connectivity.state, .idle)
        } catch {
          XCTFail("Unexpected error")
        }
      }
      
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: 1_000_000_000)
          XCTAssertEqual(connectivity.state, .waiting)
          try await connectivity.waitForConnectivity()
        } catch let error as WebSocket.Connectivity.Error {
          XCTAssertEqual(error, WebSocket.Connectivity.Error.invalid)
          XCTAssertEqual(connectivity.state, .waiting)
          connectivity.cancel()
        } catch {
          XCTFail("Unexpected error")
        }
      }
    }
  }
}
