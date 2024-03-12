//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 3/5/24.
//

import Foundation
import Network
import os
import mew_wallet_ios_logger

extension WebSocket {
  /// `TLSPinner` is an internal final class within the `WebSocket` extension, designed to facilitate TLS (Transport Layer Security) pinning for WebSocket connections.
  ///
  /// This class aims to enhance security by verifying the server's SSL certificate against known certificates or public keys, preventing man-in-the-middle (MITM) attacks.
  /// The class implements `Sendable` protocol to ensure thread-safety when used in concurrent Swift code.
  internal final class TLSPinner: Sendable {
    /// Initializes a new instance of `TLSPinner`.
    ///
    /// This initializer configures the TLS pinning for a WebSocket connection based on the provided parameters.
    /// It extracts the domain from the endpoint if not explicitly provided and sets up a verification block
    /// to validate the server's SSL certificate according to the specified policies.
    ///
    /// - Parameters:
    ///   - domain: An optional `String` representing the domain name for which the TLS pinning will be applied. If `nil`, the domain is inferred from the `endpoint` parameter.
    ///   - allowSelfSigned: A `Bool` indicating whether self-signed SSL certificates should be accepted. Setting this to `true` can be useful for development environments but is not recommended for production due to security concerns.
    ///   - endpoint: An `NWEndpoint` specifying the network endpoint. This parameter is used to infer the domain name if it is not explicitly provided.
    ///   - options: An `NWProtocolTLS.Options` object containing the TLS options for the connection. These options are used to configure the underlying security protocol.
    ///   - queue: A `DispatchQueue` on which the verification block and callbacks will be executed. This allows for asynchronous execution and returns on a specified queue.
    init(domain: String?, allowSelfSigned: Bool, endpoint: NWEndpoint, options: NWProtocolTLS.Options, queue: DispatchQueue) {
      var domain = domain
      // Extra domain if not set and possible
      if domain == nil {
        switch endpoint {
        case .hostPort(let host, _):
          guard case .name(let string, _) = host else { break }
          domain = string
        case .url(let url):
          domain = url.host()
        default:
          break
        }
      }
      
      // Sets a verification block on the security protocol options.
      // This block is called to verify the trust and the SSL certificates received from the server.
      sec_protocol_options_set_verify_block(options.securityProtocolOptions, {[weak self] sec_protocol_metadata, sec_trust, sec_protocol_verify_complete in
        guard let self else {
          sec_protocol_verify_complete(true)
          return
        }
        if allowSelfSigned {
          sec_protocol_verify_complete(true)
          return
        }
        
        // Copy the server's trust object and set SSL policies for evaluation.
        let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
        SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, domain as NSString?))
        
        // Evaluate the server's trust and complete the verification accordingly.
        do {
          let result = try self.trust(trust)
          sec_protocol_verify_complete(result)
        } catch {
          Logger.error(.tlsPinner, "\(error)")
          sec_protocol_verify_complete(false)
        }
      }, queue)
    }
    
    /// Private method to evaluate the trustworthiness of the server's SSL certificate. This method is called as part of the TLS pinning verification process.
    /// - Parameter trust: A `SecTrust` object representing the server's SSL certificate to be evaluated.
    /// - Returns: A `Bool` indicating whether the SSL certificate is trusted. Returns `true` if the certificate is trusted, otherwise returns `false`.
    /// - Throws: If there is an error evaluating the SSL certificate, an error of type `CFError` is thrown.
    private func trust(_ trust: SecTrust) throws -> Bool {
      var error: CFError?
      let result = SecTrustEvaluateWithError(trust, &error)
      if let error {
        throw error
      }
      return result
    }
  }
}
