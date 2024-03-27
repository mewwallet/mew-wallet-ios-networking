import Foundation

public enum SocketClientError: Error, Sendable {
  case badFormat
  case responseEmpty
  case error(Int)
  case timeout
  case noConnection
  case connected
}
