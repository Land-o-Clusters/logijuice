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
      let hosting = NSHostingController(rootView: SettingsView(model: model, notifier: model.notifier))
      let w = NSWindow(contentViewController: hosting)
      w.title = "LogiJuice"
      w.styleMask = [.titled, .closable, .miniaturizable]
      w.isReleasedWhenClosed = false
      w.center()
      window = w
    }
    AppModel.shared.notifier.refreshAuthorization()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
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

  var body: some View {
    Form {
      Section("Devices") {
        if model.snapshot.devices.isEmpty {
          Text("No devices yet. Plug in your Logi Bolt receiver and wake your devices.").foregroundStyle(.secondary)
        }
        ForEach(model.snapshot.devices) { device in
          DeviceSettingsRow(model: model, device: device)
        }
      }
      Section("Menu bar") {
        Toggle("Also show devices that are low or charging", isOn: $model.settings.showAlertingInMenuBar)
        Picker("Show percentage", selection: $model.settings.percentDisplay) {
          Text("When low").tag(PercentDisplay.whenLow)
          Text("Always").tag(PercentDisplay.always)
        }
        if !model.menuBarVisible {
          Text("Nothing is shown right now. Reopen LogiJuice (Spotlight or Finder) to get back here.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Section("Alerts") {
        LevelList(profile: $model.settings.profile, showAdvanced: showAdvanced)
        DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
          Stepper("Hold nudges at most \(model.settings.maxWaitHours) h",
                  value: $model.settings.maxWaitHours, in: 1...24)
          DatePicker("End of day", selection: endOfDay, displayedComponents: .hourAndMinute)
          Toggle("Notify when fully charged", isOn: $model.settings.fullyChargedEnabled)
        }
      }
      Section("General") {
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
      }
    }
    .formStyle(.grouped)
    .frame(width: 600)
    .frame(minHeight: 560)
  }
}

struct DeviceSettingsRow: View {
  @ObservedObject var model: AppModel
  let device: SnapshotDevice
  @State private var nickname = ""

  private var pinned: Binding<Bool> {
    Binding(get: { model.isPinned(device.id) }, set: { model.setPinned($0, for: device.id) })
  }

  private var custom: Binding<Bool> {
    Binding(
      get: { model.alertOverride(for: device.id) != nil },
      set: { model.setAlertOverride($0 ? model.settings.profile : nil, for: device.id) })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        Image(systemName: device.kind.symbolName).frame(width: 22)
        TextField(device.name, text: $nickname)
          .textFieldStyle(.plain)
          .frame(maxWidth: 200)
          .onSubmit { model.setNickname(nickname, for: device.id) }
        Spacer()
        Text(Format.subtitle(device, now: Date())).font(.caption).foregroundStyle(.secondary)
        Text(device.level.map(Format.level) ?? "—").monospacedDigit()
          .foregroundStyle(device.tint.color ?? Color.primary)
      }
      HStack(spacing: 16) {
        Toggle("Always show in menu bar", isOn: pinned)
        Toggle("Custom alerts", isOn: custom)
      }
      .font(.caption)
      .padding(.leading, 32)
      if let override = model.alertOverride(for: device.id) {
        LevelList(profile: Binding(get: { override }, set: { model.setAlertOverride($0, for: device.id) }),
                  showAdvanced: false)
          .padding(.leading, 32)
      }
    }
    .onAppear { nickname = device.nickname ?? "" }
    .onDisappear {
      if nickname != (device.nickname ?? "") { model.setNickname(nickname, for: device.id) }
    }
  }
}
