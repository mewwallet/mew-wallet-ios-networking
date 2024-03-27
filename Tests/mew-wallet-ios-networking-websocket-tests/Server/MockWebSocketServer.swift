//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 2/22/24.
//

import Foundation
import Network
import os
import wcpm_logger

@MainActor final class MockWebSocketServer {
  enum Error: Swift.Error {
    case badConfiguration
    case cantRun(Swift.Error)
  }
  private let port: NWEndpoint.Port
  private var listener: NWListener?
  private let listenerQueue: DispatchQueue = .init(label: "mew-wallet-ios-networking-websocket.tests.serverQueue", qos: .utility)
  private let parameters: NWParameters
  private var connections: [UUID: Connection] = [:]
  private var pingTimer: Timer?
  
  public var pingReceived: Bool = false
  public var pongReceived: Bool = false

  @MainActor init(port: UInt16) throws {
    guard let port = NWEndpoint.Port(rawValue: port) else {
      throw Error.badConfiguration
    }
    self.port = port
    parameters = .tcp
    parameters.allowLocalEndpointReuse = true
    parameters.includePeerToPeer = true
    
    let options = NWProtocolWebSocket.Options()
    options.autoReplyPing = true
    parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
  }
  
  func run() throws {
    do {
      self.pingReceived = false
      self.pongReceived = false
      if listener == nil {
        listener = try NWListener(using: self.parameters, on: self.port)
      }
      listener?.stateUpdateHandler = {[weak self] state in
        Task { @MainActor [weak self] in
          self?._process(state: state)
        }
      }
      listener?.newConnectionHandler = {[weak self] connection in
        Task { @MainActor [weak self] in
          self?._process(connection: connection)
        }
      }
      listener?.start(queue: listenerQueue)
    } catch {
      throw Error.cantRun(error)
    }
  }
  
  func shutdown() {
    connections.forEach { (key: UUID, value: Connection) in
      value.connection.forceCancel()
    }
    connections.removeAll()
    
    if listener?.state != .cancelled {
      listener?.cancel()
    }
    listener = nil
  }
  
  func broadcast(message: String) {
    self.connections.forEach { (_, value: Connection) in
      value.send(message)
    }
  }
  
  func broadcast(data: Data) {
    self.connections.forEach { (_, value: Connection) in
      value.send(data)
    }
  }
  
  // MARK: - Private
  
  private func _process(state: NWListener.State) {
    switch state {
    case .setup:
      Logger.debug(.mockWebSocketServer, ">> 🟨 Server: setup")
    case .waiting(let error):
      Logger.debug(.mockWebSocketServer, ">> 🟧 Server: Waiting", metadata: [
        "error": "\(error)"
      ])
    case .ready:
      Logger.debug(.mockWebSocketServer, ">> 🟩 Server: Ready")
    case .failed(let error):
      Logger.debug(.mockWebSocketServer, ">> ❌ Server: Failed", metadata: [
        "error": "\(error)"
      ])
    case .cancelled:
      Logger.debug(.mockWebSocketServer, ">> 🟥 Server: Cancelled")
    @unknown default:
      Logger.debug(.mockWebSocketServer, ">> ❓ Server: Unknown.", metadata: [
        "state": "\(state)"
      ])
    }
    if state == .ready {
      self.pingTimer = Timer(timeInterval: 1.0, repeats: true, block: {[weak self] _ in
        Task { @MainActor [weak self] in
          self?._ping()
        }
      })
      self.pingTimer?.tolerance = 0.1
      RunLoop.main.add(self.pingTimer!, forMode: .common)
    } else {
      self.pingTimer?.invalidate()
      self.pingTimer = nil
    }
  }
  
  private func _process(connection: NWConnection) {
    let connection = Connection(connection)
    self.connections[connection.id] = connection
    Logger.debug(.mockWebSocketServer, ">> 🟩 Server: New connection", metadata: [
      "id": "\(connection.id)"
    ])
    
    connection.run()
    
    connection.eventHandler = {[weak self] connection, event in
      switch event {
      case .text(let string):
        connection.send(string)
      case .binary(let data):
        connection.send(data)
      case .close:
        break
      case .ping:
        self?.pingReceived = true
        connection.pong()
      case .pong:
        self?.pongReceived = true
        break
      }
    }
  }
  
  private func _ping() {
    self.connections.forEach { (key: UUID, value: Connection) in
      DispatchQueue.main.async {
        value.ping()
      }
    }
  }
}
