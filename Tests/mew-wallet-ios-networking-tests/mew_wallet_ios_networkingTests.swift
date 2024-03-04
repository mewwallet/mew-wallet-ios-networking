import XCTest
import Combine
@testable import mew_wallet_ios_networking

final class mew_wallet_ios_networkingTests: XCTestCase {
  var cancellables = Set<AnyCancellable>()
    
  func test() async {
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
      let result: Data = try await NetworkTask.shared.run(config: config)
      debugPrint("Answer! \(String(data: result, encoding: .utf8) ?? "")")
    } catch {
      debugPrint("Error! \(error)")
    }
  }
}

enum TestMEWPath: NetworkPath {
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
