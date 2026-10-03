import Foundation

/// One completed discharge (from a charge to the next), summarised. Kept for two years.
public struct RunSummary: Hashable, Sendable, Codable {
  public var start: Date
  public var end: Date
  public var startPercent: Int
  public var endPercent: Int
  /// Drain in percent per day (positive).
  public var perDay: Double

  public var daysPerCharge: Double { perDay > 0 ? 100 / perDay : 0 }
}

/// Battery health inferred from usage: Logitech's protocol reports no capacity or cycle count, so these are estimates.
public struct HealthLog: Hashable, Sendable, Codable {
  public var runs: [RunSummary] = []
  /// Percent gained while charging, per Mac that observed it. Summed for cycles; merged by max per Mac.
  public var chargeGain: [String: Double] = [:]
  public var since: Date?

  public init() {}

  public var cycles: Double { chargeGain.values.reduce(0, +) / 100 }

  static let sameRunWindow: TimeInterval = 12 * 3600

  public static func merge(_ a: HealthLog?, _ b: HealthLog?) -> HealthLog? {
    guard let a else { return b }
    guard let b else { return a }
    var out = a
    for run in b.runs where !out.runs.contains(where: { abs($0.start.timeIntervalSince(run.start)) < sameRunWindow }) {
      out.runs.append(run)
    }
    out.runs.sort { $0.start < $1.start }
    for (mac, gain) in b.chargeGain { out.chargeGain[mac] = max(out.chargeGain[mac] ?? 0, gain) }
    out.since = [a.since, b.since].compactMap { $0 }.min()
    return out
  }
}

public struct HealthReport: Hashable, Sendable, Codable {
  public static let runsNeeded = 3
  public static let runsForTrend = 6

  public var completedRuns: Int
  /// Median days per full charge over the last three runs.
  public var daysPerCharge: Double?
  /// Change of the last three runs against the first three (needs six runs).
  public var changePercent: Double?
  public var baselineDate: Date?
  public var cycles: Double
  public var since: Date?
  /// Days per charge for each run, oldest first (for the sparkline).
  public var series: [Double]

  public init(completedRuns: Int, daysPerCharge: Double?, changePercent: Double?, baselineDate: Date?, cycles: Double,
              since: Date?, series: [Double]) {
    self.completedRuns = completedRuns
    self.daysPerCharge = daysPerCharge
    self.changePercent = changePercent
    self.baselineDate = baselineDate
    self.cycles = cycles
    self.since = since
    self.series = series
  }

  public var ready: Bool { completedRuns >= Self.runsNeeded }
}

public enum HealthTracker {
  public static let retention: TimeInterval = 2 * 365 * 86_400
  public static let drainAlertRatio = 2.0
  static let drainWindow: TimeInterval = 7 * 86_400
  static let drainMinimumSpan: TimeInterval = 86_400
  static let drainMinimumDrop = 5.0

  /// Folds one new local reading into the log. `history` is the device's readings *before* `reading`.
  public static func update(_ log: HealthLog?, previous: Reading?, reading: Reading, history: [Reading],
                            macID: String) -> HealthLog {
    var log = log ?? HealthLog()
    if log.since == nil { log.since = reading.observedAt }
    guard let previous, case .percent(let before) = previous.level, case .percent(let after) = reading.level else {
      return log
    }
    let gain = after - before
    let chargeSized = gain >= Int(Forecaster.riseSplit)
    if gain > 0 && (reading.charging || previous.charging || chargeSized) {
      log.chargeGain[macID, default: 0] += Double(gain)
    }
    // A discharge run just ended: charging began, or the level jumped by a charge's worth.
    let runEnded = (reading.charging && !previous.charging) || (!reading.charging && !previous.charging && chargeSized)
    if runEnded,
      let run = Forecaster.dischargeRuns(history.sorted { $0.observedAt < $1.observedAt }).last,
      Forecaster.isConfident(run), let slope = Forecaster.theilSenSlope(run), slope < 0,
      let first = run.first, let last = run.last,
      !log.runs.contains(where: { abs($0.start.timeIntervalSince(first.t)) < HealthLog.sameRunWindow })
    {
      log.runs.append(RunSummary(start: first.t, end: last.t, startPercent: Int(first.p), endPercent: Int(last.p),
                                 perDay: -slope))
    }
    let cutoff = reading.observedAt.addingTimeInterval(-retention)
    log.runs = log.runs.filter { $0.end >= cutoff }.sorted { $0.start < $1.start }
    return log
  }

  public static func report(_ log: HealthLog?) -> HealthReport {
    let runs = log?.runs ?? []
    let series = runs.map(\.daysPerCharge)
    let ready = runs.count >= HealthReport.runsNeeded
    let recent = ready ? median(Array(series.suffix(3))) : nil
    var change: Double?
    var baselineDate: Date?
    if runs.count >= HealthReport.runsForTrend, let base = median(Array(series.prefix(3))), let recent, base > 0 {
      change = (recent - base) / base * 100
      baselineDate = runs.first?.start
    }
    return HealthReport(completedRuns: runs.count, daysPerCharge: recent, changePercent: change,
                        baselineDate: baselineDate, cycles: log?.cycles ?? 0, since: log?.since, series: series)
  }

  /// How much faster than usual the current discharge is going (2.0 = twice as fast). nil until there's a baseline
  /// (three runs) and the current run has at least a day and a 5-point drop in the last week.
  public static func drainRatio(_ log: HealthLog?, history: [Reading], now: Date) -> Double? {
    guard let runs = log?.runs, runs.count >= HealthReport.runsNeeded,
      let typical = median(runs.map(\.perDay)), typical > 0
    else { return nil }
    let sorted = history.sorted { $0.observedAt < $1.observedAt }
    guard let latest = sorted.last, !latest.charging, let run = Forecaster.dischargeRuns(sorted).last else { return nil }
    let recent = run.filter { now.timeIntervalSince($0.t) <= drainWindow }
    guard let first = recent.first, let last = recent.last,
      last.t.timeIntervalSince(first.t) >= drainMinimumSpan, first.p - last.p >= drainMinimumDrop,
      let slope = Forecaster.theilSenSlope(recent), slope < 0
    else { return nil }
    return -slope / typical
  }

  /// Start of the discharge run in progress, so a drain alert fires at most once per run.
  public static func currentRunStart(_ history: [Reading]) -> Date? {
    Forecaster.dischargeRuns(history.sorted { $0.observedAt < $1.observedAt }).last?.first?.t
  }

  static func median(_ xs: [Double]) -> Double? {
    guard !xs.isEmpty else { return nil }
    let s = xs.sorted()
    let m = s.count / 2
    return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
  }
}
