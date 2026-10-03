import AppKit
import JuiceCore
import SwiftUI

extension IconTint {
  var nsColor: NSColor? {
    switch self {
    case .none: return nil
    case .yellow: return .systemYellow
    case .red: return NSColor.systemRed.withAlphaComponent(0.85)
    }
  }

  var color: Color? { nsColor.map(Color.init(nsColor:)) }
}

struct MenuBarLabel: View {
  let devices: [SnapshotDevice]
  let display: PercentDisplay

  var body: some View {
    Image(nsImage: Self.image(devices: devices, display: display))
  }

  /// One silhouette gauge per shown device (spec §7, amended 2026-10-03).
  static func image(devices: [SnapshotDevice], display: PercentDisplay) -> NSImage {
    MenuBarIcon.render(devices.map { MenuBarIcon.gauge(for: $0, text: Format.menuBarText($0, display: display)) })
  }
}

extension MenuBarIcon {
  static func gauge(for d: SnapshotDevice, text: String?) -> Gauge {
    let symbols = d.kind.gaugeSymbols
    return Gauge(
      outline: symbols.outline, fill: symbols.fill,
      fraction: Double(d.level?.equivalentPercent ?? 0) / 100, tint: d.tint.nsColor,
      charging: d.charging && d.live, text: text)
  }
}

/// Native-menu-like feedback: highlight on hover, darker while pressed.
struct MenuRowButtonStyle: ButtonStyle {
  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 4)
      .padding(.horizontal, 8)
      .background(
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.accentColor.opacity(configuration.isPressed ? 0.45 : hovering ? 0.25 : 0)))
      .contentShape(Rectangle())
      .onHover { hovering = $0 }
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
      if device.charging { Image(systemName: "bolt.fill").foregroundStyle(Color(nsColor: MenuBarIcon.chargingColor)) }
      Text(device.level.map(Format.level) ?? "—")
        .monospacedDigit()
        .foregroundStyle(device.tint.color ?? Color.primary)
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
    .buttonStyle(MenuRowButtonStyle())
    .padding(10)
    .frame(width: 300)
  }
}
