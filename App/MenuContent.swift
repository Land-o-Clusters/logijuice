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

/// Native-menu-like feedback: a soft highlight on hover, firmer while pressed.
struct MenuRowButtonStyle: ButtonStyle {
  var verticalPadding: CGFloat = 3
  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, verticalPadding)
      .padding(.horizontal, 9)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : hovering ? 0.09 : 0)))
      .contentShape(Rectangle())
      .onHover { hovering = $0 }
  }
}

/// Menu metrics: 13 pt rows, 5 pt panel inset, 9 pt row inset (as macOS menus).
private enum MenuMetrics {
  static let inset: CGFloat = 5
  static let rowInset: CGFloat = 9
  static let icon: CGFloat = 26
  static let iconGap: CGFloat = 9
}

struct DeviceRow: View {
  let device: SnapshotDevice
  let now: Date
  let expanded: Bool

  var body: some View {
    HStack(spacing: MenuMetrics.iconGap) {
      Image(nsImage: MenuBarIcon.render([MenuBarIcon.gauge(for: device, text: nil)], pointSize: 15))
        .foregroundStyle(.primary)
        .frame(width: MenuMetrics.icon)
      VStack(alignment: .leading, spacing: 1) {
        Text(device.displayName).font(.system(size: 13, weight: .medium)).lineLimit(1)
        let sub = Format.subtitle(device, now: now)
        if !sub.isEmpty { Text(sub).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
      }
      Spacer(minLength: 6)
      if device.charging {
        Image(systemName: "bolt.fill").font(.system(size: 10))
          .foregroundStyle(Color(nsColor: MenuBarIcon.chargingColor))
      }
      Text(device.level.map(Format.level) ?? "—")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(device.tint.color ?? Color.primary)
      Image(systemName: "chevron.right")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.tertiary)
        .rotationEffect(.degrees(expanded ? 90 : 0))
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint(expanded ? "Hides details" : "Shows details")
  }
}

/// The rows from `Format.details`, label column muted. Values are selectable so a serial can be copied.
struct DeviceDetails: View {
  let device: SnapshotDevice
  var compact = false

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: compact ? 3 : 6) {
      ForEach(Format.details(device, now: Date()), id: \.label) { row in
        GridRow {
          Text(row.label).foregroundStyle(.secondary)
          Text(row.value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .font(compact ? .system(size: 11) : .callout)
  }
}

private struct MenuHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct MenuContent: View {
  @ObservedObject var model: AppModel
  @State private var expanded: DeviceID?
  private var debugMenu: Bool { UserDefaults.standard.bool(forKey: "debugMenu") }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if model.snapshot.devices.isEmpty {
        note(model.receiverPresent ? "Waiting for a device to wake up…" : "Plug in your Logi Bolt receiver.")
      }
      ForEach(model.snapshot.devices) { d in
        Button {
          withAnimation(.easeInOut(duration: MenuPanel.resizeDuration)) { expanded = expanded == d.id ? nil : d.id }
        } label: {
          DeviceRow(device: d, now: Date(), expanded: expanded == d.id)
        }
        .buttonStyle(MenuRowButtonStyle(verticalPadding: 5))
        if expanded == d.id {
          DeviceDetails(device: d, compact: true)
            .padding(.leading, MenuMetrics.rowInset + MenuMetrics.icon + MenuMetrics.iconGap)
            .padding(.trailing, MenuMetrics.rowInset)
            .padding(.top, 1)
            .padding(.bottom, 7)
            .transition(.opacity)
        }
      }
      if !model.receiverPresent && !model.snapshot.devices.isEmpty {
        note("Receiver not connected to this Mac")
      }
      Divider().padding(.horizontal, MenuMetrics.rowInset).padding(.vertical, 5)
      Group {
        Button("Settings…") { SettingsWindowController.shared.show() }
        if OptionsPlus.isInstalled { Button("Open Logi Options+") { MenuPanel.shared.close(); OptionsPlus.open() } }
        if debugMenu {
          Button("Debug: simulate 18% Test Mouse (Low, waits for a moment)") { model.simulateLowBattery(percent: 18) }
          Button("Debug: simulate 8% Test Mouse (Very low, immediate)") { model.simulateLowBattery(percent: 8) }
          Button("Debug: forget Test Mouse") { model.forgetTestDevice() }
          Button("Debug: re-add the menu bar item") {
            NotificationCenter.default.post(name: StatusItemWatchdog.forceReinsert, object: nil)
          }
        }
        Button("Quit LogiJuice") { NSApp.terminate(nil) }
      }
      .font(.system(size: 13))
      .buttonStyle(MenuRowButtonStyle())
    }
    .padding(MenuMetrics.inset)
    .frame(width: 280)
    .fixedSize(horizontal: false, vertical: true)
    .background(MenuPanelAnchor())
    .background(GeometryReader { geo in
      Color.clear.preference(key: MenuHeightKey.self, value: geo.size.height)
    })
    .onPreferenceChange(MenuHeightKey.self) { height in
      DispatchQueue.main.async { MenuPanel.shared.fit(contentHeight: height) }
    }
    // Pinned to the top while the window animates: growing reveals rows downward, shrinking slides the bottom up.
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11))
      .foregroundStyle(.secondary)
      .padding(.horizontal, MenuMetrics.rowInset)
      .padding(.vertical, 4)
  }
}
