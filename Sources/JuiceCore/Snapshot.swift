import Foundation

public struct SnapshotDevice: Hashable, Sendable, Codable, Identifiable {
  public var id: DeviceID
  public var name: String
  public var nickname: String?
  public var kind: DeviceKind
  public var level: BatteryLevel?
  public var charging: Bool
  public var lastSeen: Date?
  public var live: Bool
  public var forecast: ForecastResult
  public var alerting: Bool
  public var tint: IconTint
  /// Present while the forecast is learning, to say how far along it is.
  public var learning: LearningProgress?

  public init(id: DeviceID, name: String, nickname: String?, kind: DeviceKind, level: BatteryLevel?,
              charging: Bool, lastSeen: Date?, live: Bool, forecast: ForecastResult, alerting: Bool,
              tint: IconTint, learning: LearningProgress? = nil) {
    self.id = id
    self.name = name
    self.nickname = nickname
    self.kind = kind
    self.level = level
    self.charging = charging
    self.lastSeen = lastSeen
    self.live = live
    self.forecast = forecast
    self.alerting = alerting
    self.tint = tint
    self.learning = learning
  }

  public var displayName: String {
    if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
    return name
  }
}

/// The only contract between the app, the widget and the CLI (spec §7).
public struct Snapshot: Hashable, Sendable, Codable {
  public static let currentSchema = 1
  public var schema: Int
  public var generatedAt: Date
  public var receiverPresent: Bool
  public var devices: [SnapshotDevice]

  public init(schema: Int = Snapshot.currentSchema, generatedAt: Date, receiverPresent: Bool,
              devices: [SnapshotDevice]) {
    self.schema = schema
    self.generatedAt = generatedAt
    self.receiverPresent = receiverPresent
    self.devices = devices
  }

  public var lowest: SnapshotDevice? {
    devices.filter { $0.level != nil }.min {
      ($0.level?.equivalentPercent ?? 101) < ($1.level?.equivalentPercent ?? 101)
    }
  }

  public static let empty = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), receiverPresent: false, devices: [])

  public static let preview = Snapshot(
    generatedAt: Date(timeIntervalSince1970: 1_800_000_000), receiverPresent: true,
    devices: [
      SnapshotDevice(id: .serial("PREVIEW-MOUSE"), name: "MX Master 3S", nickname: nil, kind: .mouse,
                     level: .percent(14), charging: false, lastSeen: Date(timeIntervalSince1970: 1_800_000_000),
                     live: true, forecast: .estimate(daysLeft: 2, emptyAt: Date(timeIntervalSince1970: 1_800_172_800)),
                     alerting: true, tint: .yellow),
      SnapshotDevice(id: .serial("PREVIEW-KEYS"), name: "MX Keys S", nickname: nil, kind: .keyboard,
                     level: .percent(72), charging: false, lastSeen: Date(timeIntervalSince1970: 1_800_000_000),
                     live: true, forecast: .learning, alerting: false, tint: .none),
    ])
}

public enum SnapshotBuilder {
  public static func build(records: [DeviceRecord], liveDevices: Set<DeviceID>, receiverPresent: Bool,
                           alerting: Set<DeviceID>, tints: [DeviceID: IconTint], now: Date) -> Snapshot {
    let devices = records.map { r -> SnapshotDevice in
      let latest = r.readings.max { $0.observedAt < $1.observedAt }
      return SnapshotDevice(
        id: r.info.id, name: r.info.name, nickname: r.nickname, kind: r.info.kind, level: latest?.level,
        charging: latest?.charging ?? false, lastSeen: latest?.observedAt, live: liveDevices.contains(r.info.id),
        forecast: Forecaster.forecast(r.readings, now: now), alerting: alerting.contains(r.info.id),
        tint: tints[r.info.id] ?? .none, learning: Forecaster.learningProgress(r.readings, now: now))
    }.sorted {
      ($0.level?.equivalentPercent ?? 101, $0.displayName) < ($1.level?.equivalentPercent ?? 101, $1.displayName)
    }
    return Snapshot(generatedAt: now, receiverPresent: receiverPresent, devices: devices)
  }
}
