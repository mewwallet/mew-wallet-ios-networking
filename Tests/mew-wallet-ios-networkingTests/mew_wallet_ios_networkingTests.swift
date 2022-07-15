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
}
