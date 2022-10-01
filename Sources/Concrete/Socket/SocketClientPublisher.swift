//
//  File.swift
//  
//
//  Created by Nail Galiaskarov on 10/1/22.
//

import Foundation
import Combine

struct SocketClientPublisher {
  private var publisher: PassthroughSubject<Result<NetworkResponse, Error>, Never>?
  private var block: ((Result<NetworkResponse, Error>) -> Void)?
  
  init(
    publisher: PassthroughSubject<Result<NetworkResponse, Error>, Never>? = nil,
    block: ((Result<NetworkResponse, Error>) -> Void)? = nil
  ) {
    self.publisher = publisher
    self.block = block
  }
  
  func send(signal: Result<NetworkResponse, Error>) {
    publisher?.send(signal)
    block?(signal)
  }
}
