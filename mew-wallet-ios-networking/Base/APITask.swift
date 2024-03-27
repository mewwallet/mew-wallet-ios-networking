//
//  File.swift
//  
//
//  Created by Mikhail Nikanorov on 9/8/22.
//

import Foundation

public final class APITask<T: Sendable>: Sendable {
  public typealias Call = @Sendable () async throws -> T
  
  internal let path: any APINetworkPath
  internal let provider: any GenericNetworkProvider
  let task: Call
  
  public init(path: any APINetworkPath, provider: GenericNetworkProvider, task: @escaping Call) {
    self.path = path
    self.provider = provider
    self.task = task
  }
  
  public func execute() async throws -> T {
    let result: T = try await self.task()
    self.provider.postProcess(task: self, result: result)
    return result
  }
}
