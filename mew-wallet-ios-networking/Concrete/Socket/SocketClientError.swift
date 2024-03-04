import Foundation

public enum SocketClientError: Error {
  case badFormat
  case responseEmpty
  case error(Int)
  case timeout
  case noConnection
  case connected
}
