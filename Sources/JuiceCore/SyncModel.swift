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
  /// When each forgotten device was forgotten, as this Mac knows it (its own forgets and other Macs').
  /// Optional and additive, so the schema stays 1 and older Macs still read the file (they ignore the key).
  public var forgotten: [DeviceID: Date]?

  public init(schema: Int = SyncFile.currentSchema, macID: String, macName: String, updatedAt: Date,
              devices: [DeviceRecord], forgotten: [DeviceID: Date]? = nil) {
    self.schema = schema
    self.macID = macID
    self.macName = macName
    self.updatedAt = updatedAt
    self.devices = devices
    self.forgotten = forgotten
  }
}

public enum SyncMerge {
  /// `forgotten` is this Mac's own list; the other Macs' lists come from their files.
  public static func merge(local: [DeviceRecord], remotes: [SyncFile], forgotten: [DeviceID: Date] = [:],
                           now: Date) -> [DeviceRecord] {
    let forgotten = self.forgotten(local: forgotten, remotes: remotes, now: now)
    var byID: [DeviceID: DeviceRecord] = [:]
    for record in applyForgotten(forgotten, to: local) { byID[record.info.id] = record }

    for file in remotes where file.schema <= SyncFile.currentSchema {
      for remote in applyForgotten(forgotten, to: file.devices) {
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

  /// A forget is kept as long as health runs are, so a Mac that comes back after months can't bring old data back.
  public static let forgetRetention = HealthTracker.retention

  /// The newest forget per device across this Mac and the others. Forgets older than `forgetRetention` are dropped.
  public static func forgotten(local: [DeviceID: Date], remotes: [SyncFile], now: Date) -> [DeviceID: Date] {
    var out: [DeviceID: Date] = [:]
    let lists = [local] + remotes.filter { $0.schema <= SyncFile.currentSchema }.compactMap(\.forgotten)
    for list in lists {
      for (id, at) in list where now.timeIntervalSince(at) < forgetRetention {
        out[id] = max(out[id] ?? at, at)
      }
    }
    return out
  }

  /// Drops everything known about a device up to its forget: readings, a name or alert override set before it, and a
  /// health log started before it. A device with nothing newer disappears; one seen again keeps only the newer data.
  public static func applyForgotten(_ forgotten: [DeviceID: Date], to records: [DeviceRecord]) -> [DeviceRecord] {
    guard !forgotten.isEmpty else { return records }
    return records.compactMap { record -> DeviceRecord? in
      guard let at = forgotten[record.id] else { return record }
      var copy = record
      copy.readings = record.readings.filter { $0.observedAt > at }
      if record.metaUpdatedAt <= at {
        copy.nickname = nil
        copy.alertOverride = nil
        copy.metaUpdatedAt = .distantPast
      }
      if let health = record.health, (health.since ?? .distantPast) <= at { copy.health = nil }
      return copy.readings.isEmpty && copy.health == nil ? nil : copy
    }
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
