import Foundation
import JuiceCore

public enum AtomicFile {
  public static func write<T: Encodable>(_ value: T, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JuiceJSON.encoder.encode(value).write(to: url, options: .atomic)
  }
}

public struct JSONFileStore<Value: Codable>: Sendable {
  public let url: URL

  public init(url: URL) { self.url = url }

  /// Missing → default. Corrupt → moved aside to `<name>.corrupt.json`, then default.
  public func load(default makeDefault: @autoclosure () -> Value) -> Value {
    guard let data = try? Data(contentsOf: url) else { return makeDefault() }
    do {
      return try JuiceJSON.decoder.decode(Value.self, from: data)
    } catch {
      let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
      try? FileManager.default.removeItem(at: backup)
      try? FileManager.default.moveItem(at: url, to: backup)
      return makeDefault()
    }
  }

  public func read() -> Value? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JuiceJSON.decoder.decode(Value.self, from: data)
  }

  public func save(_ value: Value) throws { try AtomicFile.write(value, to: url) }
}

/// This Mac's private state: local readings, alert state, pending nudges.
public struct LocalState: Hashable, Sendable, Codable {
  public var records: [DeviceRecord] = []
  public var alertStates: [DeviceID: DeviceAlertState] = [:]
  public var scheduler = NudgeScheduler(maxWait: 8 * 3600)

  public init() {}
}

public typealias SettingsStore = JSONFileStore<Settings>
public typealias StateStore = JSONFileStore<LocalState>
public typealias SnapshotStore = JSONFileStore<Snapshot>
