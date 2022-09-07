import XCTest
import Combine
@testable import mew_wallet_ios_networking

final class mew_wallet_ios_networkingTests: XCTestCase {
  var cancellables = Set<AnyCancellable>()
    func testExample() throws {
      
      let expectation = XCTestExpectation(description: "wait for completion")
      
      mew_wallet_ios_networking().runNetworkCall(config: nil)
        .sink(receiveCompletion: { completion in
          debugPrint(">>> \(completion)")
          expectation.fulfill()
        }, receiveValue: { value in
          debugPrint("received \(value)")
        })
        .store(in: &cancellables)
      
      wait(for: [expectation], timeout: 60.0)
    }
  
  func test2() async {
    let networkClient = RESTClient(session: .shared)
    
    let baseURL = URL(string: "https://mainnet.mewwallet.dev")!
    let request = RESTRequestModel(baseURL: baseURL,
                                   networkPath: TestMEWPath.v2_stake_info,
                                   method: .get,
                                   headers: nil,
                                   body: nil)
    
    let config = NetworkRequestConfig(request: .rest(request),
                                      client: networkClient,
                                      deserialization: .disable,
                                      validation: .disable,
                                      conversion: .disable,
                                      mapping: .disable)
    do {
      guard let result = try await NetworkTask.shared.run(config: config) as? Data else { return }
      debugPrint("Answer! \(String(data: result, encoding: .utf8) ?? "")")
    } catch {
      debugPrint("Error! \(error)")
    }
  }
}

enum TestMEWPath: NetworkPath {
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
