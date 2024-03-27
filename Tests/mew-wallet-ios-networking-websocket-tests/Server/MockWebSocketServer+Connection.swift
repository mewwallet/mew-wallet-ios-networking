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

extension MockWebSocketServer {
  final class Connection {
    enum Event {
      case text(String?)
      case binary(Data?)
      case close
      case ping
      case pong
    }
    let id: UUID = UUID()
    let connection: NWConnection
    
    private let connectionQueue: DispatchQueue = .global(qos: .utility)
    
    var eventHandler: ((Connection, Event) -> Void)?
    
    init(_ connection: NWConnection) {
      self.connection = connection
    }
    
    func run() {
      connection.stateUpdateHandler = { [weak self] state in
        self?._process(state: state)
      }
      connection.start(queue: connectionQueue)
    }
    
    func stop() {
      connection.cancel()
    }
    
    // MARK: - Sending
    
    func pong() {
      let meta = NWProtocolWebSocket.Metadata(opcode: .pong)
      let context = NWConnection.ContentContext(identifier: "pong", metadata: [meta])
      send(data: nil, context: context)
    }
    
    func send(_ text: String?) {
      let data = text?.data(using: .utf8)
      let meta = NWProtocolWebSocket.Metadata(opcode: .text)
      let context = NWConnection.ContentContext(identifier: "text", metadata: [meta])
      send(data: data, context: context)
    }
    
    func send(_ data: Data?) {
      let meta = NWProtocolWebSocket.Metadata(opcode: .binary)
      let context = NWConnection.ContentContext(identifier: "binary", metadata: [meta])
      send(data: data, context: context)
    }
    
    func ping() {
      let meta = NWProtocolWebSocket.Metadata(opcode: .ping)
      meta.setPongHandler(self.connectionQueue) {[weak self] error in
        guard let self else { return }
        Logger.debug(.mockWebSocketServer, ">> Client[\(self.id)]. Pong error: \(String(describing: error))")
      }
      let context = NWConnection.ContentContext(identifier: "ping", metadata: [meta])
      Logger.debug(.mockWebSocketServer, ">> Client[\(id)]. Send ping")
      send(data: nil, context: context)
    }
    
    private func send(data: Data?, context: NWConnection.ContentContext) {
      connection.send(content: data,
                      contentContext: context,
                      isComplete: true,
                      completion: .contentProcessed({[weak self] error in
        guard let self else { return }
        if let error {
          Logger.debug(.mockWebSocketServer, ">> Client[\(id)]. Sent: error - \(error)")
          return
        }
        Logger.debug(.mockWebSocketServer, ">> Client[\(id)]. Sent: size - \(data?.count ?? 0)")
      }))
    }
    
    // MARK: - Private
    
    private func listen() {
      connection.receiveMessage {[weak self] content, contentContext, isComplete, error in
        guard let self else { return }
        if let contentContext {
          self._process(content: content, context: contentContext)
        }
        
        if error == nil {
          self.listen()
        }
      }
    }
    
    private func _process(state: NWConnection.State) {
      switch state {
      case .setup:
        Logger.debug(.mockWebSocketServer, "__ 🟨 Client[\(id)]: Setup")
      case .waiting(let error):
        Logger.debug(.mockWebSocketServer, "__ 🟧 Client[\(id)]: Waiting. Error: \(error.localizedDescription)")
      case .preparing:
        Logger.debug(.mockWebSocketServer, "__ 🟨 Client[\(id)]: Preparing")
      case .ready:
        Logger.debug(.mockWebSocketServer, "__ 🟩 Client[\(id)]: Ready")
        self.listen()
      case .failed(let error):
        Logger.debug(.mockWebSocketServer, "__ ❌ Client[\(id)]: Failed. Error: \(error.localizedDescription)")
      case .cancelled:
        Logger.debug(.mockWebSocketServer, "__ 🟥 Client[\(id)]: Cancelled")
      @unknown default:
        Logger.debug(.mockWebSocketServer, "__ ❓ Client[\(id)]: Unknown. State: \(state)")
      }
    }
    
    private func _process(content: Data?, context: NWConnection.ContentContext) {
      guard let metadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata else { return }
      
      guard let eventHandler else { return }
      
      switch metadata.opcode {
      case .binary:
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Binary: size - \(content?.count ?? 0)")
        eventHandler(self, .binary(content))
      case .cont:
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Cont")
      case .text:
        let string: String?
        if let content {
          string = String(data: content, encoding: .utf8)
        } else {
          string = nil
        }
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Text: content - \(String(describing: string))")
        eventHandler(self, .text(string))
      case .close:
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Close")
        eventHandler(self, .close)
      case .ping:
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Ping")
        eventHandler(self, .ping)
      case .pong:
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Pong")
        eventHandler(self, .pong)
      @unknown default:
        Logger.debug(.mockWebSocketServer, "<< Client[\(id)]. Unknown: opcode - \(metadata.opcode)")
      }
    }
  }
}
