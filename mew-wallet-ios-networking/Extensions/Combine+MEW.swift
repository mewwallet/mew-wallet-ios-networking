import Foundation
import Combine

extension Publisher {
  func asyncMap<T>(
    _ transform: @escaping (Output) async throws -> T
  ) -> Publishers.FlatMap<Future<Result<T,Error>, Never>, Self> {
    flatMap { value in
      Future { promise in
        Task {
          do {
            let output = try await transform(value)
            promise(.success(.success(output)))
          } catch {
            promise(.success(.failure(error)))
          }
        }
      }
    }
  }
}
