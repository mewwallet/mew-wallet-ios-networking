//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 2/22/24.
//

import Foundation
import Network
import os
import mew_wallet_ios_extensions
import mew_wallet_ios_logger

extension WebSocket.Connectivity {
  enum Error: Swift.Error {
    case cancelled
    case failed
    case invalid
    case tls
  }
}

extension WebSocket.Connectivity {
  enum State {
    case idle
    case waiting
  }
}

extension WebSocket {
  /// The WebSocket.Connectivity class is an extension of the WebSocket class, focusing on the management of WebSocket connection states and monitoring network connectivity changes. It is built to be thread-safe and utilizes Apple's Network framework (NWConnection) for network tasks.
  public final class Connectivity: Sendable {
    private let _state = ThreadSafe<State>(.idle)
    /// A read-only property that returns the current state of the WebSocket connectivity, encapsulated within a ThreadSafe wrapper for thread safety.
    var state: State {
      return _state.value
    }
    
    /// The WebSocket configuration
    private let configuration: WebSocket.Configuration
    
    /// A ThreadSafe wrapper around an optional NWConnection, used to monitor the WebSocket connection.
    private let monitor = ThreadSafe<NWConnection?>(nil)
    private let pinner: WebSocket.TLSPinner?
    /// A DispatchQueue used for executing network monitoring tasks.
    private let monitorQueue: DispatchQueue = .init(label: "mew-wallet-ios-networking-websocket.connectivity", qos: .utility)
    
    /// A ThreadSafe wrapper around an optional CheckedContinuation, used for asynchronous waiting.
    private let continuation = ThreadSafe<CheckedContinuation<Void, any Swift.Error>?>(nil)
    /// A ThreadSafe wrapper around an optional Task, used to handle delay before retrying a connection.
    private let delayTask = ThreadSafe<Task<Void, Never>?>(nil)
    
    /// The Endpoing of the WebSocket connection to monitor.
    private let endpoint: NWEndpoint
    /// `NWParameters` used for the WebSocket connection, depending on whether the connection is secure (wss) or not (ws).
    private let parameters: NWParameters
    
    /// A convenience initializer that sets up the `WebSocket.Connectivity` connection with optional headers and a delay.
    /// - Parameters:
    ///   - url: The URL of the WebSocket connection to monitor.
    ///   - headers: Extra headers for connection
    ///   - options: `WebSocket` protocol options
    ///   - configuration: `WebSocket.Configuration` with connection settings
    public convenience init(url: URL, headers: [(name: String, value: String)], options: NWProtocolWebSocket.Options? = nil, configuration: WebSocket.Configuration = .default) throws {
      // Options
      let options = NWProtocolWebSocket.Options()
      if !headers.isEmpty {
        options.setAdditionalHeaders(headers)
      }
      
      try self.init(
        url: url,
        options: [options],
        configuration: configuration
      )
    }
    
    /// A convenience initializer that sets up the `WebSocket.Connectivity` connection with the specified URL, parameters, and an optional delay.
    /// - Parameters:
    ///   - url: The URL of the WebSocket connection to monitor.
    ///   - options: `WebSocket` protocol options
    ///   - configuration: `WebSocket.Configuration` with connection settings
    public convenience init(url: URL, options: [NWProtocolOptions] = [], configuration: WebSocket.Configuration = .default) throws {
      try self.init(endpoint: .url(url), options: options, configuration: configuration)
    }
    
    /// The primary initializer that configures the `WebSocket.Connectivity` with the specified URL, parameters, and an optional delay.
    /// - Parameters:
    ///   - endpoint: The `NWEndpoint` of the WebSocket connection to monitor.
    ///   - options: `WebSocket` protocol options
    ///   - configuration: `WebSocket.Configuration` with connection settings
    public init(endpoint: NWEndpoint, options: [NWProtocolOptions] = [], configuration: WebSocket.Configuration = .default) throws {
      // TLS Protocol
      var protocolTLSOptions = (options.first(where: { $0 is NWProtocolTLS.Options }) as? NWProtocolTLS.Options)
      switch configuration.tls {
      case .disabled:
        // We have nothing to do here, just use what we have
        self.pinner = nil
      case .unpinned:
        // Make sure we have options
        protocolTLSOptions = protocolTLSOptions ?? NWProtocolTLS.Options()
        self.pinner = nil
      case .pinned(let domain, let allowSelfSigned):
        
        // Make sure we have options and pinning is enabled
        protocolTLSOptions = protocolTLSOptions ?? NWProtocolTLS.Options()
        self.pinner = TLSPinner(domain: domain, allowSelfSigned: allowSelfSigned, endpoint: endpoint, options: protocolTLSOptions!, queue: self.monitorQueue)
      }
      
      // TCP Protocol
      let protocolTCPOptions = (options.first(where: { $0 is NWProtocolTCP.Options }) as? NWProtocolTCP.Options) ?? NWProtocolTCP.Options()
      protocolTCPOptions.connectionTimeout = 5
      protocolTCPOptions.persistTimeout = 5
      
      // WebSocket Protocol
      let protocolWebSocketOptions = (options.first(where: { $0 is NWProtocolWebSocket.Options }) as? NWProtocolWebSocket.Options) ?? NWProtocolWebSocket.Options()
      protocolWebSocketOptions.skipHandshake = true
      protocolWebSocketOptions.autoReplyPing = configuration.autoReplyPing

      // Prepare NWParameters
      let parametersWebSocket = NWParameters(tls: protocolTLSOptions, tcp: protocolTCPOptions)
      
      // Add WebSocket to NWParameters
      parametersWebSocket.defaultProtocolStack.applicationProtocols.insert(protocolWebSocketOptions, at: 0)
      
      // Prepare NWParameters
      let parameters = NWParameters(tls: protocolTLSOptions, tcp: protocolTCPOptions)
      
      // Add WebSocket to NWParameters
      parameters.defaultProtocolStack.applicationProtocols.insert(protocolWebSocketOptions, at: 0)
      
      self.configuration = configuration
      
      self.endpoint = endpoint
      self.parameters = parameters
      Logger.trace(.connectivity, "Initialized", metadata: [
        "endpoint": "\(endpoint)",
        "parameters": "\(parameters)",
        "configuration": "\(configuration)"
      ])
    }
    
    /// Ensures that the connection is cancelled, any ongoing tasks are stopped, and resources are properly released upon deinitialization.
    deinit {
      Logger.trace(.connectivity, "Deinit", metadata: [
        "endpoint": "\(endpoint)",
        "parameters": "\(parameters)",
        "configuration": "\(configuration)"
      ])
      self.continuation.value?.resume(throwing: Error.cancelled)
      self.delayTask.value?.cancel()
      self.monitor.value?.cancel()
    }
    
    /// Asynchronously waits for the WebSocket connection to become available. Throws an error if the waiting is cancelled or if an invalid state occurs.
    /// Throws:
    /// - `Error.cancelled`: If the waiting operation is cancelled before the connection is established.
    /// - `Error.failed`: If delay is nil and endpoint is not reachable
    /// - `Error.invalid`: If the method is called more than once without a successful connection establishment or if an invalid state is detected.
    public func waitForConnectivity() async throws {
      Logger.debug(.connectivity, "Waits for connectivity", metadata: [
        "endpoint": "\(endpoint)"
      ])
      try await withCheckedThrowingContinuation {[weak self] (continuation: CheckedContinuation<Void, any Swift.Error>) in
        guard let self else {
          continuation.resume(throwing: Error.cancelled)
          return
        }
        
        let success = self.continuation.write { stored in
          guard stored == nil else { return false }
          stored = continuation
          return true
        }
        
        guard success else {
          continuation.resume(throwing: Error.invalid)
          return
        }

        self.run()
      }
      
      Logger.debug(.connectivity, "Connectivity reached", metadata: [
        "endpoint": "\(endpoint)"
      ])
    }
    
    /// Cancels the current connection attempt and any ongoing delay tasks.
    public func cancel() {
      Logger.debug(.connectivity, "Cancelled", metadata: [
        "endpoint": "\(endpoint)"
      ])
      self.stop(with: .failure(WebSocket.Connectivity.Error.cancelled))
    }
    
    // MARK: - State Handler
    
    /// Handles changes in the network connection state, managing retries and cancellation based on the current state and configured delay.
    /// - Parameter state: The new state of the connection, as reported by NWConnection.
    private func stateChanged(_ state: NWConnection.State) {
      Logger.debug(.connectivity, "State changed", metadata: [
        "endpoint": "\(endpoint)",
        "state": "\(state)"
      ])
      guard self.continuation.value != nil else {
        self.stop(with: nil)
        return
      }
      
      switch state {
      case .cancelled:
        self.stop(with: .failure(Connectivity.Error.cancelled))
      case .waiting(let error):
        switch error {
        case .tls:
          self.stop(with: .failure(.tls))
        default:
          break
        }
        guard let delay = self.configuration.reconnectDelay else {
          self.stop(with: .failure(Connectivity.Error.failed))
          return
        }
        self.delayTask.write { task in
          task = Task {[weak self] in
            guard let self else { return }
            do {
              try await Task.sleep(nanoseconds: delay)
              try Task.checkCancellation()
              self.restartMonitor()
            } catch { }
          }
        }
      case .ready:
        self.stop(with: .success(()))
      default:
        break
      }
    }
    
    // MARK: - Private
    
    /// Initiates the monitoring of the WebSocket connection using the configured parameters.
    private func run() {
      Logger.trace(.connectivity, "Start monitor", metadata: [
        "endpoint": "\(endpoint)"
      ])
      guard self._state.write({ state in
        guard state != .waiting else { return false }
        state = .waiting
        return true
      }) else { return }
      
      self.delayTask.write { task in
        task?.cancel()
        task = nil
      }
      
      self.monitor.write {[weak self] monitor in
        guard let self else { return }
        monitor = NWConnection(to: self.endpoint, using: self.parameters)
        monitor?.stateUpdateHandler = {[weak self] state in
          guard let self else { return }
          self.stateChanged(state)
        }
      }
      
      self.monitor.value?.start(queue: monitorQueue)
    }
    
    /// Stops the connection attempt and monitoring, optionally resuming the waiting continuation with a result.
    /// - Parameter result: An optional Result indicating the outcome of the connectivity attempt. Can be either `.success(())` to indicate a successful connection or `.failure(Error)` to indicate an error.
    private func stop(with result: Result<Void, Error>?) {
      Logger.trace(.connectivity, "Stop monitor", metadata: [
        "endpoint": "\(endpoint)"
      ])
      self.delayTask.write { task in
        task?.cancel()
        task = nil
      }
      
      self._state.write {[weak self] state in
        defer {
          state = .idle
        }
        self?.monitor.write { monitor in
          monitor?.cancel()
          monitor = nil
        }
      }
      
      if let result {
        // Endpoint is reachable now
        self.continuation.write { continuation in
          continuation?.resume(with: result)
          continuation = nil
        }
      }
    }
    
    private func restartMonitor() {
      Logger.trace(.connectivity, "Restart monitor", metadata: [
        "endpoint": "\(endpoint)"
      ])
      guard self.continuation.value != nil else {
        self.stop(with: nil)
        return
      }
      self.delayTask.write { task in
        task?.cancel()
        task = nil
      }
      self.monitor.value?.restart()
    }
  }
}
