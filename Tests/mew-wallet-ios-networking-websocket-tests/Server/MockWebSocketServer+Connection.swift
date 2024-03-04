//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 2/22/24.
//

import Foundation
import Network

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
        debugPrint(">> Client[\(self.id)]. Pong error: \(String(describing: error))")
      }
      let context = NWConnection.ContentContext(identifier: "ping", metadata: [meta])
      debugPrint(">> Client[\(id)]. Send ping")
      send(data: nil, context: context)
    }
    
    private func send(data: Data?, context: NWConnection.ContentContext) {
      connection.send(content: data,
                      contentContext: context,
                      isComplete: true,
                      completion: .contentProcessed({[weak self] error in
        guard let self else { return }
        if let error {
          debugPrint(">> Client[\(id)]. Sent: error - \(error)")
          return
        }
        debugPrint(">> Client[\(id)]. Sent: size - \(data?.count ?? 0)")
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
        debugPrint("__ 🟨 Client[\(id)]: Setup")
      case .waiting(let error):
        debugPrint("__ 🟧 Client[\(id)]: Waiting. Error: \(error.localizedDescription)")
      case .preparing:
        debugPrint("__ 🟨 Client[\(id)]: Preparing")
      case .ready:
        debugPrint("__ 🟩 Client[\(id)]: Ready")
        self.listen()
      case .failed(let error):
        debugPrint("__ ❌ Client[\(id)]: Failed. Error: \(error.localizedDescription)")
      case .cancelled:
        debugPrint("__ 🟥 Client[\(id)]: Cancelled")
      @unknown default:
        debugPrint("__ ❓ Client[\(id)]: Unknown. State: \(state)")
      }
    }
    
    private func _process(content: Data?, context: NWConnection.ContentContext) {
      guard let metadata = context.protocolMetadata.first as? NWProtocolWebSocket.Metadata else { return }
      
      guard let eventHandler else { return }
      
      switch metadata.opcode {
      case .binary:
        debugPrint("<< Client[\(id)]. Binary: size - \(content?.count ?? 0)")
        eventHandler(self, .binary(content))
      case .cont:
        debugPrint("<< Client[\(id)]. Cont")
      case .text:
        let string: String?
        if let content {
          string = String(data: content, encoding: .utf8)
        } else {
          string = nil
        }
        debugPrint("<< Client[\(id)]. Text: content - \(String(describing: string))")
        eventHandler(self, .text(string))
      case .close:
        debugPrint("<< Client[\(id)]. Close")
        eventHandler(self, .close)
      case .ping:
        debugPrint("<< Client[\(id)]. Ping")
        eventHandler(self, .ping)
      case .pong:
        debugPrint("<< Client[\(id)]. Pong")
        eventHandler(self, .pong)
      @unknown default:
        debugPrint("<< Client[\(id)]. Unknown: opcode - \(metadata.opcode)")
      }
    }
  }
}
