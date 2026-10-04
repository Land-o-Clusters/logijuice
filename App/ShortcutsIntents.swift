// Shortcuts actions. Built only into signed apps (scripts/build-app.sh sets LOGIJUICE_APP_INTENTS): macOS runs
// App Intents only for an app with a Team ID, and rejects an ad-hoc-signed one (`requiresValidatedBundle`), so an
// unsigned build would list actions that always fail.
#if LOGIJUICE_APP_INTENTS
import AppIntents
import JuiceCore
import JuiceStore

private func currentSnapshot() -> Snapshot? {
  SnapshotStore(url: JuicePaths.standard().snapshotURL).read()
}

private func summary(_ d: SnapshotDevice) -> String {
  Format.statusLine(d, now: Date())
}

struct LogitechDeviceEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Logitech Device"
  static var defaultQuery = LogitechDeviceQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct LogitechDeviceQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [LogitechDeviceEntity] {
    try await suggestedEntities().filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [LogitechDeviceEntity] {
    (currentSnapshot()?.devices ?? []).map { LogitechDeviceEntity(id: $0.id.rawValue, name: $0.displayName) }
  }
}

struct GetDeviceBatteryIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Device Battery"
  static var description = IntentDescription("Battery level, charging state and time left for one Logitech device.")

  @Parameter(title: "Device") var device: LogitechDeviceEntity

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let d = currentSnapshot()?.devices.first(where: { $0.id.rawValue == device.id }) else {
      return .result(value: "Unknown", dialog: "LogiJuice hasn't seen \(device.name) yet.")
    }
    let text = summary(d)
    return .result(value: text, dialog: "\(text)")
  }
}

struct GetLowestBatteryIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Lowest Battery"
  static var description = IntentDescription("The Logitech device with the lowest battery.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let d = currentSnapshot()?.lowest else {
      return .result(value: "Unknown", dialog: "LogiJuice has no battery readings yet.")
    }
    let text = summary(d)
    return .result(value: text, dialog: "\(text)")
  }
}

struct LogiJuiceShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: GetLowestBatteryIntent(),
                phrases: ["Get lowest battery in \(.applicationName)", "Which battery is low in \(.applicationName)"],
                shortTitle: "Lowest Battery", systemImageName: "battery.25percent")
  }
}
#endif
