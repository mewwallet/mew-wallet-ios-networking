import Foundation
import UIKit

public typealias RestSubscriptionBlock = () -> Void

struct RestSubscriptionTask {
  let id: String
  let timer: Timer
  let interval: TimeInterval
  let block: RestSubscriptionBlock
}

public final class RestSubscriptionHandler {
  private var subscriptions = [String: RestSubscriptionTask]()
  
  public init() {
    NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
  }
  
  public func scheduleSubscription(id: String, interval: TimeInterval, block: @escaping RestSubscriptionBlock) {
    guard subscriptions[id] == nil else { return }
    
    let timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(handleTimer), userInfo: id, repeats: true)
    subscriptions[id] = RestSubscriptionTask(
      id: id,
      timer: timer,
      interval: interval,
      block: block
    )
  }
  
  @objc
  private func handleTimer(_ timer: Timer) {
    guard let id = timer.userInfo as? String else {
      return
    }
    
    subscriptions[id]?.block()
  }
  
  @objc
  private func handleDidBecomeActive() {
    var values = subscriptions.values
    subscriptions.removeAll()
    values.forEach {
      $0.timer.invalidate()
      scheduleSubscription(id: $0.id, interval: $0.interval, block: $0.block)
    }
  }
}
