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
      let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 780),
                       styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                       backing: .buffered, defer: false)
      w.contentView = NSHostingView(rootView: SettingsView(model: model, notifier: model.notifier))
      w.contentMinSize = NSSize(width: 640, height: 560)
      w.title = "LogiJuice"
      w.titleVisibility = .hidden
      w.titlebarAppearsTransparent = true
      w.isMovableByWindowBackground = true
      w.isOpaque = false
      w.backgroundColor = .clear
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
  /// (Layout only: behind-window blur and glass don't render into this capture.)
  private func snapshotForDebugIfRequested() {
    guard let path = UserDefaults.standard.string(forKey: "debugSettingsSnapshotPath"), !path.isEmpty else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      guard let view = self?.window?.contentView,
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
      else { return }
      view.cacheDisplay(in: view.bounds, to: rep)
      try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
      let metrics = "window \(self?.window?.frame.size ?? .zero) content \(view.bounds.size) fitting \(view.fittingSize)"
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

  private var devices: [SnapshotDevice] { model.snapshot.devices }

  var body: some View {
    ZStack {
      WindowBackdrop().ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          hero
          devicesSection
          menuBarSection
          alertsSection
          generalSection
        }
        .padding(.horizontal, 26)
        .padding(.top, 6)
        .padding(.bottom, 26)
      }
    }
    .frame(minWidth: 640, idealWidth: 700, maxWidth: .infinity, minHeight: 560, idealHeight: 780, maxHeight: .infinity)
  }

  // MARK: Hero — the window opens on your batteries.

  private var hero: some View {
    HStack(alignment: .bottom, spacing: 34) {
      if devices.isEmpty {
        Text("Plug in your Logi Bolt receiver and wake a device.")
          .font(.system(.title3, design: .rounded))
          .foregroundStyle(.secondary)
      }
      ForEach(devices) { d in
        VStack(spacing: 6) {
          Image(nsImage: MenuBarIcon.render([MenuBarIcon.gauge(for: d, text: nil)], pointSize: 40))
            .foregroundStyle(.primary)
          Text(d.level.map(Format.level) ?? "—")
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(d.tint.color ?? Color.primary)
          Text(d.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
      }
      Spacer(minLength: 0)
    }
    .padding(.top, 28)
    .padding(.horizontal, 6)
  }

  // MARK: Sections

  private var devicesSection: some View {
    GlassSection(title: "Devices") {
      if devices.isEmpty {
        Text("No devices yet.").foregroundStyle(.secondary)
      }
      ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
        if index > 0 { GlassDivider() }
        DeviceSettingsRow(model: model, device: device)
      }
    }
  }

  private var menuBarSection: some View {
    GlassSection(title: "Menu bar") {
      GlassRow(label: "Also show devices that are low or charging") {
        Toggle("Also show devices that are low or charging", isOn: $model.settings.showAlertingInMenuBar)
          .labelsHidden()
          .toggleStyle(.switch)
      }
      GlassDivider()
      GlassRow(label: "Show percentage") {
        GlassDropdown(selection: $model.settings.percentDisplay,
                      options: [(.whenLow, "When low"), (.always, "Always")],
                      accessibilityName: "Show percentage")
      }
      if !model.menuBarVisible {
        Text("Nothing is in the menu bar right now. Reopen LogiJuice from Spotlight or Finder to get back here.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var alertsSection: some View {
    GlassSection(title: "Alerts") {
      ThresholdBar(profile: $model.settings.profile, devices: devices)
      ForEach($model.settings.profile.levels) { $level in
        GlassDivider()
        LevelRow(level: $level, showAdvanced: showAdvanced)
      }
      GlassDivider()
      DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
        VStack(alignment: .leading, spacing: 12) {
          GlassRow(label: "Hold a waiting alert at most") {
            Stepper("\(model.settings.maxWaitHours) h", value: $model.settings.maxWaitHours, in: 1...24)
              .monospacedDigit()
          }
          GlassRow(label: "End of day") {
            DatePicker("End of day", selection: endOfDay, displayedComponents: .hourAndMinute).labelsHidden()
          }
          GlassRow(label: "Notify when fully charged") {
            Toggle("Notify when fully charged", isOn: $model.settings.fullyChargedEnabled)
              .labelsHidden().toggleStyle(.switch)
          }
        }
        .padding(.top, 10)
      }
    }
  }

  private var generalSection: some View {
    GlassSection(title: "General") {
      GlassRow(label: "Launch at login") {
        Toggle("Launch at login", isOn: $launchAtLogin)
          .labelsHidden().toggleStyle(.switch)
          .onChange(of: launchAtLogin) { _, on in
            LoginItem.set(on)
            launchAtLogin = LoginItem.isEnabled
          }
      }
      GlassDivider()
      GlassRow(label: "Sync across Macs with iCloud Drive") {
        Toggle("Sync across Macs", isOn: $model.settings.syncEnabled)
          .labelsHidden().toggleStyle(.switch)
          .disabled(!model.syncAvailable)
      }
      if !model.syncAvailable {
        Text("Sync is off because iCloud Drive isn't enabled on this Mac.").font(.caption).foregroundStyle(.secondary)
      }
      if !notifier.authorized {
        GlassDivider()
        GlassRow(label: "Notifications are off for LogiJuice") {
          Button("Open Notification Settings") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
          }
        }
      }
      if OptionsPlus.isInstalled {
        GlassDivider()
        GlassRow(label: "Button remapping and pairing") {
          Button("Open Logi Options+") { OptionsPlus.open() }
            .buttonStyle(.plain)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .glassCapsule()
        }
      }
    }
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
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Image(nsImage: MenuBarIcon.render([MenuBarIcon.gauge(for: device, text: nil)], pointSize: 22))
          .foregroundStyle(.primary)
          .frame(width: 30)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            TextField("Name", text: $nickname, prompt: Text(device.name))
              .labelsHidden()
              .textFieldStyle(.plain)
              .font(.system(.headline, design: .rounded))
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
        Spacer(minLength: 8)
        Toggle("In menu bar", isOn: pinned).toggleStyle(ChipToggleStyle())
        Toggle("Custom alerts", isOn: custom).toggleStyle(ChipToggleStyle())
      }
      if let override = model.alertOverride(for: device.id) {
        VStack(alignment: .leading, spacing: 10) {
          ThresholdBar(profile: Binding(get: { override }, set: { model.setAlertOverride($0, for: device.id) }),
                       devices: [device])
          ForEach(Binding(get: { override }, set: { model.setAlertOverride($0, for: device.id) }).levels) { $level in
            LevelRow(level: $level, showAdvanced: false)
          }
        }
        .padding(12)
        .glassPanel(cornerRadius: 14)
        .padding(.leading, 42)
      }
    }
    .onAppear { nickname = device.displayName }
    .onChange(of: editingName) { _, editing in if !editing { commitName() } }
  }
}
