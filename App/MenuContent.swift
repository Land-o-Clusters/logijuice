import AppKit
import JuiceCore
import SwiftUI

struct MenuBarLabel: View {
  let snapshot: Snapshot
  let tinted: Bool

  var body: some View {
    Image(nsImage: Self.image(percent: snapshot.lowest?.level?.equivalentPercent, tinted: tinted))
  }

  static func image(percent: Int?, tinted: Bool) -> NSImage {
    let base = NSImage(systemSymbolName: Format.batterySymbol(percent: percent),
                       accessibilityDescription: "Logitech battery") ?? NSImage()
    guard tinted, let red = base.withSymbolConfiguration(.init(paletteColors: [.systemRed])) else {
      base.isTemplate = true
      return base
    }
    red.isTemplate = false
    return red
  }
}

struct DeviceRow: View {
  let device: SnapshotDevice
  let now: Date

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: device.kind.symbolName).frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(device.displayName).font(.headline)
        let sub = Format.subtitle(device, now: now)
        if !sub.isEmpty { Text(sub).font(.caption).foregroundStyle(.secondary) }
      }
      Spacer()
      if device.charging { Image(systemName: "bolt.fill").foregroundStyle(.yellow) }
      Text(device.level.map(Format.level) ?? "—")
        .monospacedDigit()
        .foregroundStyle(device.tinted ? Color.red : Color.primary)
    }
  }
}

struct MenuContent: View {
  @ObservedObject var model: AppModel
  private var debugMenu: Bool { UserDefaults.standard.bool(forKey: "debugMenu") }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if model.snapshot.devices.isEmpty {
        Text(model.receiverPresent ? "Waiting for a device to wake up…" : "Plug in your Logi Bolt receiver.")
          .foregroundStyle(.secondary)
      }
      ForEach(model.snapshot.devices) { DeviceRow(device: $0, now: Date()) }
      if !model.receiverPresent && !model.snapshot.devices.isEmpty {
        Text("Receiver not connected to this Mac").font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      Button("Settings…") { SettingsWindowController.shared.show() }
      if OptionsPlus.isInstalled { Button("Open Logi Options+") { OptionsPlus.open() } }
      if debugMenu {
        Button("Debug: simulate 18% Test Mouse (Low, waits for a moment)") { model.simulateLowBattery(percent: 18) }
        Button("Debug: simulate 8% Test Mouse (Very low, immediate)") { model.simulateLowBattery(percent: 8) }
        Button("Debug: forget Test Mouse") { model.forgetTestDevice() }
      }
      Button("Quit LogiJuice") { NSApp.terminate(nil) }
    }
    .buttonStyle(.borderless)
    .padding(14)
    .frame(width: 300)
  }
}
