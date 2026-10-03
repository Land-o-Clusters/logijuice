import AppKit
import JuiceCore
import SwiftUI

@MainActor
final class SettingsWindowController {
  static let shared = SettingsWindowController()
  private var window: NSWindow?

  func show() {
    if window == nil {
      let model = AppModel.shared
      let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
                       styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
      w.contentView = NSHostingView(rootView: SettingsView(model: model, notifier: model.notifier))
      // macOS 27's grouped Form needs ~744pt (≈640pt column + 52pt margins); narrower clips both edges.
      w.contentMinSize = NSSize(width: 760, height: 520)
      w.title = "LogiJuice"
      w.isReleasedWhenClosed = false
      w.center()
      window = w
    }
    AppModel.shared.notifier.refreshAuthorization()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    snapshotForDebugIfRequested()
  }

  /// Debug aid: `defaults write com.penguinspecz.logijuice debugSettingsSnapshotPath /tmp/x.png` makes the window
  /// write a PNG of itself a second after opening, so layout can be checked without screen-recording rights.
  private func snapshotForDebugIfRequested() {
    guard let path = UserDefaults.standard.string(forKey: "debugSettingsSnapshotPath"), !path.isEmpty else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      guard let view = self?.window?.contentView,
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
      else { return }
      view.cacheDisplay(in: view.bounds, to: rep)
      try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
      let metrics = "window \(self?.window?.frame.size ?? .zero) content \(view.bounds.size) "
        + "fitting \(view.fittingSize) intrinsic \(view.intrinsicContentSize) "
        + "subviews \(view.subviews.map { "\(type(of: $0)) \($0.frame)" })"
      try? metrics.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
    }
  }
}

struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var notifier: Notifier
  @State private var showAdvanced = false
  @State private var launchAtLogin = LoginItem.isEnabled

  private var endOfDay: Binding<Date> {
    Binding(
      get: {
        Calendar.current.date(bySettingHour: model.settings.endOfDayHour, minute: model.settings.endOfDayMinute,
                              second: 0, of: Date()) ?? Date()
      },
      set: {
        let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
        model.settings.endOfDayHour = c.hour ?? 17
        model.settings.endOfDayMinute = c.minute ?? 30
      })
  }

  /// Debug aid for layout bisection: section names listed in `debugSettingsHide` are omitted.
  private var hidden: [String] { UserDefaults.standard.stringArray(forKey: "debugSettingsHide") ?? [] }

  var body: some View {
    Form {
      if !hidden.contains("devices") { Section("Devices") {
        if model.snapshot.devices.isEmpty {
          Text("No devices yet. Plug in your Logi Bolt receiver and wake your devices.").foregroundStyle(.secondary)
        }
        ForEach(model.snapshot.devices) { device in
          DeviceSettingsRow(model: model, device: device)
        }
      } }
      if !hidden.contains("menubar") { Section("Menu bar") {
        Toggle("Also show devices that are low or charging", isOn: $model.settings.showAlertingInMenuBar)
        Picker("Show percentage", selection: $model.settings.percentDisplay) {
          Text("When low").tag(PercentDisplay.whenLow)
          Text("Always").tag(PercentDisplay.always)
        }
        if !model.menuBarVisible {
          Text("Nothing is shown right now. Reopen LogiJuice (Spotlight or Finder) to get back here.")
            .font(.caption).foregroundStyle(.secondary)
        }
      } }
      if !hidden.contains("alerts") { Section("Alerts") {
        LevelList(profile: $model.settings.profile, showAdvanced: showAdvanced, devices: model.snapshot.devices)
        DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
          Stepper("Hold nudges at most \(model.settings.maxWaitHours) h",
                  value: $model.settings.maxWaitHours, in: 1...24)
          DatePicker("End of day", selection: endOfDay, displayedComponents: .hourAndMinute)
          Toggle("Notify when fully charged", isOn: $model.settings.fullyChargedEnabled)
        }
      } }
      if !hidden.contains("general") { Section("General") {
        Toggle("Launch at login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, on in
            LoginItem.set(on)
            launchAtLogin = LoginItem.isEnabled
          }
        Toggle("Sync across Macs (iCloud Drive)", isOn: $model.settings.syncEnabled)
          .disabled(!model.syncAvailable)
        if !model.syncAvailable {
          Text("Sync off: iCloud Drive not enabled").font(.caption).foregroundStyle(.secondary)
        }
        if !notifier.authorized {
          HStack {
            Text("Notifications are off for LogiJuice.").foregroundStyle(.red)
            Button("Open Notification Settings") {
              NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
          }
        }
        if OptionsPlus.isInstalled { Button("Open Logi Options+") { OptionsPlus.open() } }
      } }
    }
    .formStyle(.grouped)
    .frame(minWidth: 760, idealWidth: 760, maxWidth: .infinity, minHeight: 520, idealHeight: 720,
           maxHeight: .infinity)
  }
}

struct DeviceSettingsRow: View {
  @ObservedObject var model: AppModel
  let device: SnapshotDevice
  @State private var nickname = ""
  @FocusState private var editingName: Bool

  private var pinned: Binding<Bool> {
    Binding(get: { model.isPinned(device.id) }, set: { model.setPinned($0, for: device.id) })
  }

  private var custom: Binding<Bool> {
    Binding(
      get: { model.alertOverride(for: device.id) != nil },
      set: { model.setAlertOverride($0 ? model.settings.profile : nil, for: device.id) })
  }

  /// The hardware name stays visible under a nickname, so a renamed device is still recognisable.
  private var detail: String {
    let parts = [device.nickname?.isEmpty == false ? device.name : nil, Format.subtitle(device, now: Date())]
    return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
  }

  /// The field shows the display name; saving the hardware name back means "no nickname".
  private func commitName() {
    let trimmed = nickname.trimmingCharacters(in: .whitespaces)
    let next = (trimmed.isEmpty || trimmed == device.name) ? "" : trimmed
    if next != (device.nickname ?? "") { model.setNickname(next, for: device.id) }
    if trimmed.isEmpty { nickname = device.name }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Image(nsImage: MenuBarIcon.render([MenuBarIcon.gauge(for: device, text: nil)], pointSize: 24))
          .foregroundStyle(.primary)
          .frame(width: 34, alignment: .center)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            TextField("Name", text: $nickname, prompt: Text(device.name))
              .labelsHidden()
              .textFieldStyle(.plain)
              .font(.headline)
              .focused($editingName)
              .fixedSize()
              .onSubmit(commitName)
            if !editingName {
              Button { editingName = true } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Rename")
                .accessibilityLabel("Rename \(device.displayName)")
            }
          }
          if !detail.isEmpty {
            Text(detail).font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer()
        Text(device.level.map(Format.level) ?? "—")
          .font(.system(size: 22, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(device.tint.color ?? Color.primary)
      }
      HStack(spacing: 20) {
        Toggle("Show in menu bar", isOn: pinned).toggleStyle(.checkbox)
        Toggle("Custom alerts", isOn: custom).toggleStyle(.checkbox)
      }
      .font(.callout)
      .padding(.leading, 46)
      if let override = model.alertOverride(for: device.id) {
        LevelList(profile: Binding(get: { override }, set: { model.setAlertOverride($0, for: device.id) }),
                  showAdvanced: false, devices: [device])
          .padding(.leading, 46)
      }
    }
    .padding(.vertical, 2)
    .onAppear { nickname = device.displayName }
    .onChange(of: editingName) { _, editing in if !editing { commitName() } }
  }
}
