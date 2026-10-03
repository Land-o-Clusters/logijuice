import Foundation

/// Everything known about one device. Metadata (nickname, override) syncs newest-wins by `metaUpdatedAt`.
public struct DeviceRecord: Hashable, Sendable, Codable, Identifiable {
  public var info: DeviceInfo
  public var nickname: String?
  public var alertOverride: AlertProfile?
  public var metaUpdatedAt: Date
  public var readings: [Reading]
  public var health: HealthLog?

  public init(info: DeviceInfo, nickname: String?, alertOverride: AlertProfile?, metaUpdatedAt: Date,
              readings: [Reading], health: HealthLog? = nil) {
    self.info = info
    self.nickname = nickname
    self.alertOverride = alertOverride
    self.metaUpdatedAt = metaUpdatedAt
    self.readings = readings
    self.health = health
  }

  public var id: DeviceID { info.id }

  public var displayName: String {
    if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
    return info.name
  }
}

/// One Mac's file in `iCloud Drive/logijuice/<macID>.json` (spec §6). Contains only that Mac's own readings.
public struct SyncFile: Hashable, Sendable, Codable {
  public static let currentSchema = 1
  public var schema: Int
  public var macID: String
  public var macName: String
  public var updatedAt: Date
  public var devices: [DeviceRecord]

  public init(schema: Int = SyncFile.currentSchema, macID: String, macName: String, updatedAt: Date,
              devices: [DeviceRecord]) {
    self.schema = schema
    self.macID = macID
    self.macName = macName
    self.updatedAt = updatedAt
    self.devices = devices
  }
}

public enum SyncMerge {
  public static func merge(local: [DeviceRecord], remotes: [SyncFile], now: Date) -> [DeviceRecord] {
    var byID: [DeviceID: DeviceRecord] = [:]
    for record in local { byID[record.info.id] = record }

    for file in remotes where file.schema <= SyncFile.currentSchema {
      for remote in file.devices {
        let retagged = remote.readings.filter { $0.source == .local }.map { r -> Reading in
          var copy = r
          copy.source = .synced(macID: file.macID)
          return copy
        }
        if var existing = byID[remote.info.id] {
          existing.readings = union(existing.readings, retagged)
          existing.health = HealthLog.merge(existing.health, remote.health)
          if remote.metaUpdatedAt > existing.metaUpdatedAt {
            existing.info = remote.info
            existing.nickname = remote.nickname
            existing.alertOverride = remote.alertOverride
            existing.metaUpdatedAt = remote.metaUpdatedAt
          }
          byID[remote.info.id] = existing
        } else {
          var fresh = remote
          fresh.readings = union([], retagged)
          byID[remote.info.id] = fresh
        }
      }
    }

    return byID.values.map { record -> DeviceRecord in
      var copy = record
      copy.readings = History.trim(copy.readings, now: now)
      return copy
    }.sorted { $0.info.id < $1.info.id }
  }

  /// Union keyed by whole second; a local reading wins over a synced one at the same second.
  static func union(_ a: [Reading], _ b: [Reading]) -> [Reading] {
    var bySecond: [Int: Reading] = [:]
    for r in a + b {
      let key = Int(r.observedAt.timeIntervalSince1970.rounded(.down))
      if let existing = bySecond[key], existing.source == .local { continue }
      bySecond[key] = r
    }
    return bySecond.values.sorted { $0.observedAt < $1.observedAt }
  }
}
