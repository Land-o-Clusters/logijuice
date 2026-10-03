import Foundation

public enum Moment: String, Hashable, Sendable, Codable {
  case screenLocked, willSleep, endOfDay, receiverDeparted, maxWait
}

public struct Delivery: Hashable, Sendable {
  public var decision: AlertDecision
  /// nil = delivered immediately (timing `.now` or fully charged).
  public var moment: Moment?

  public init(decision: AlertDecision, moment: Moment?) {
    self.decision = decision
    self.moment = moment
  }
}

/// Holds `.nextMoment` alerts until a natural moment (spec §4). Pure: the app feeds it events.
public struct NudgeScheduler: Hashable, Sendable, Codable {
  public struct Pending: Hashable, Sendable, Codable {
    public var decision: AlertDecision
    public var queuedAt: Date
  }

  public var maxWait: TimeInterval
  public private(set) var pending: [Pending] = []

  public init(maxWait: TimeInterval) { self.maxWait = maxWait }

  public mutating func schedule(_ decision: AlertDecision, now: Date) -> [Delivery] {
    if case .level(_, _, .nextMoment, _, _) = decision.kind {
      let queuedAt = pending.first { $0.decision.device == decision.device }?.queuedAt ?? now
      pending.removeAll { $0.decision.device == decision.device }
      pending.append(Pending(decision: decision, queuedAt: queuedAt))
      return []
    }
    if case .level = decision.kind {
      pending.removeAll { $0.decision.device == decision.device }
    }
    return [Delivery(decision: decision, moment: nil)]
  }

  public mutating func onMoment(_ moment: Moment, now: Date) -> [Delivery] {
    let out = pending.map { Delivery(decision: $0.decision, moment: moment) }
    pending = []
    return out
  }

  public mutating func onTick(now: Date) -> [Delivery] {
    let due = pending.filter { now.timeIntervalSince($0.queuedAt) >= maxWait }
    pending.removeAll { now.timeIntervalSince($0.queuedAt) >= maxWait }
    return due.map { Delivery(decision: $0.decision, moment: .maxWait) }
  }

  public mutating func dropPending(for device: DeviceID) {
    pending.removeAll { $0.decision.device == device }
  }

  public static func nextEndOfDay(after date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
    let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    if today > date { return today }
    return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
  }
}
