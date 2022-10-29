import Foundation
import Combine

public enum SomeError: Error {
  case anyerror
}

public struct mew_wallet_ios_networking {
  public init() {
  }
  
  var currentTask: Task<Void, Never>?
  
  func runNetworkCall(config: Any?) -> AnyPublisher<Any, Error> {
    let publisher = PassthroughSubject<Any, Error>()
    Task {
      enum MEWPath: NetworkPath {
        var isSocket: Bool { false }
        
        case v2_stake_info
        var path: String {
          switch self {
          case .v2_stake_info:
            return "v2/stake/info"
          }
        }
        
        var query: [URLQueryItem]? {
          return nil
        }
      }
      debugPrint("start")
      let baseURL = URL(string: "https://mainnet.mewwallet.dev")!
      let builder = try RESTRequestBuilder(baseURL: baseURL, path: nil)
      
      let networkClient = RESTClient(session: .shared)
      
//      let task_build = try TaskBuildNetworkCall(builder: builder)
      let task_network = TaskNetworkRequest(client: networkClient)
      
//      let task_deserialize = DecodingTask()
//      let task_repeating = RepeatingTask()
      
//      task_repeating.runInternalTask()
      
      try await Task.sleep(nanoseconds: 5000000000)
      
      var i = 0
      repeat {
        i += 1
//        let value = try await task_repeating.process()
//        publisher.send(value)
//        if value % 2 == 0 {
//          publisher.send(completion: .failure(SomeError.anyerror))
//          return
//        }
      } while i < 10
      
      // Build request
      let requestModel = RESTRequestModel()
        .networkPath(path: MEWPath.v2_stake_info)
        .method(.get)
//      let networkCall = NetworkRequestConfig(client: networkClient,
//                                             requestModel: ) NetworkCallConfig(requestModel: requestModel)
      
      
      
//      let request = try await task_build.process(networkCall)
      
      // do while not cancelled or error?
//      let response = try await task_network.process(request)
//      let model: ResponseStruct = try await task_deserialize.process(response)
//      publisher.send(model)
      
      try await Task.sleep(nanoseconds: 9000000000)
      
      publisher.send(1)
      publisher.send(completion: .finished)
    }
    return publisher.eraseToAnyPublisher()
  }
}


//final class DecodingTask {
//  let deserializer: ResponseDeserializer
//
//  init() {
//    self.deserializer = JSONDeserializer(decoder: JSONDecoder())
//  }
//
//  func process<T: Decodable>(_ response: NetworkResponse) async throws -> T {
//    return try await self.deserializer.deserialize(response)
//  }
//}
//
//final class RepeatingTask {
//  var pool: [UInt32] = []
//  
//  var currentTask: Task<Void, Error>?
//  var currentContinuation: CheckedContinuation<UInt32, Error>?
//  
//  enum TaskError: Error {
//    case cancelled
//  }
//  
//  deinit {
//    currentTask?.cancel()
//    currentContinuation?.resume(throwing: TaskError.cancelled)
//    currentContinuation = nil
//  }
//  
//  func process() async throws -> UInt32 {
//    guard self.pool.isEmpty else {
//      return self.pool.removeFirst()
//    }
//    return try await withCheckedThrowingContinuation {[weak self] continuation in
//      guard let strongSelf = self else { return }
//      guard strongSelf.pool.isEmpty else {
//        debugPrint("??? [direct]")
//        let value = strongSelf.pool.removeFirst()
//        continuation.resume(returning: value)
//        return
//      }
//      debugPrint("??? [waiting]")
//      self?.currentContinuation = continuation
//    }
//  }
//  
//  func runInternalTask() {
//    currentTask = Task {
//      try await Task.sleep(nanoseconds: 2000000000)
//      guard !Task.isCancelled else { return }
//      self._process(value: arc4random())
//      runInternalTask()
//    }
//  }
//  
//  func _process(value: UInt32) {
//    
//    guard self.pool.isEmpty else {
//      debugPrint(">>> \(value) [pool]")
//      self.pool.append(value)
//      return
//    }
//    if let currentContinuation = currentContinuation {
//      debugPrint(">>> \(value) [continue]")
//      currentContinuation.resume(returning: value)
//      self.currentContinuation = nil
//    } else {
//      debugPrint(">>> \(value) [pool 0]")
//      self.pool.append(value)
//    }
//  }
//}

// Build request ->
// execute request ->
// deserialize response? ->
// validate response? ->
// convert response?
// map response ->
// return response

struct ResponseStruct: Decodable {
  let total_staked: String
  let apr: String
  let mew_fee: String
  let mew_fee_percent: String
  let estimated_activation_timestamp: String
}
