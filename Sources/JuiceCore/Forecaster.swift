import Foundation

/// Time-left forecast from local + synced history (spec §5).
public enum Forecaster {
  public static let minimumDrop = 10.0
  public static let minimumSpan: TimeInterval = 2 * 86_400
  static let riseSplit = 10.0
  static let maxPointsPerRun = 500

  struct Point: Hashable {
    var t: Date
    var p: Double
  }

  public static func forecast(_ readings: [Reading], now: Date) -> ForecastResult {
    let sorted = readings.sorted { $0.observedAt < $1.observedAt }
    guard let latest = sorted.last else { return .learning }
    guard case .percent(let latestPercent) = latest.level else { return .unavailable }
    if latest.charging { return .learning }

    let runs = dischargeRuns(sorted)
    guard let current = runs.last else { return .learning }
    var slope: Double?
    if isConfident(current) {
      slope = theilSenSlope(current)
    } else {
      for run in runs.dropLast().reversed() where isConfident(run) {
        slope = theilSenSlope(run)
        break
      }
    }
    guard let perDay = slope, perDay < 0 else { return .learning }

    let daysFromLatest = Double(latestPercent) / -perDay
    let emptyAt = latest.observedAt.addingTimeInterval(daysFromLatest * 86_400)
    let daysLeft = max(0, emptyAt.timeIntervalSince(now) / 86_400)
    return .estimate(daysLeft: daysLeft, emptyAt: emptyAt)
  }

  static func dischargeRuns(_ sorted: [Reading]) -> [[Point]] {
    var runs: [[Point]] = []
    var current: [Point] = []
    for reading in sorted {
      guard case .percent(let p) = reading.level else { continue }
      if reading.charging {
        if !current.isEmpty { runs.append(current); current = [] }
        continue
      }
      let value = Double(p)
      if let last = current.last, value >= last.p + riseSplit {
        runs.append(current)
        current = []
      }
      current.append(Point(t: reading.observedAt, p: value))
    }
    if !current.isEmpty { runs.append(current) }
    return runs
  }

  static func isConfident(_ run: [Point]) -> Bool {
    guard let first = run.first, let last = run.last else { return false }
    return first.p - last.p >= minimumDrop && last.t.timeIntervalSince(first.t) >= minimumSpan
  }

  /// Median of pairwise slopes, in percent per day. Robust to coarse steps and outliers.
  static func theilSenSlope(_ run: [Point]) -> Double? {
    let points = Array(run.suffix(maxPointsPerRun))
    guard let origin = points.first?.t else { return nil }
    let xs = points.map { $0.t.timeIntervalSince(origin) / 86_400 }
    var slopes: [Double] = []
    slopes.reserveCapacity(points.count * points.count / 2)
    for i in 0..<points.count {
      for j in (i + 1)..<points.count where xs[j] > xs[i] {
        slopes.append((points[j].p - points[i].p) / (xs[j] - xs[i]))
      }
    }
    guard !slopes.isEmpty else { return nil }
    slopes.sort()
    let mid = slopes.count / 2
    return slopes.count % 2 == 1 ? slopes[mid] : (slopes[mid - 1] + slopes[mid]) / 2
  }
}
