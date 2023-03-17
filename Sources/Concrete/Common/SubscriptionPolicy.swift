import Foundation

public enum SubscriptionPolicy {
  case subscribe(id: String, interval: TimeInterval)
  case none
}
