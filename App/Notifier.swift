import AppKit
import JuiceCore
import UserNotifications

@MainActor
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
  static let categoryID = "logijuice.battery"
  @Published private(set) var authorized = true
  var onSnooze: ((DeviceID) -> Void)?
  private let center = UNUserNotificationCenter.current()

  func start() {
    center.delegate = self
    var actions = [UNNotificationAction(identifier: "snooze", title: "Snooze 1 day")]
    if OptionsPlus.isInstalled {
      actions.append(UNNotificationAction(identifier: "openOptions", title: "Open Logi Options+", options: [.foreground]))
    }
    center.setNotificationCategories([
      UNNotificationCategory(identifier: Self.categoryID, actions: actions, intentIdentifiers: [])
    ])
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      Task { @MainActor in self.authorized = granted }
    }
  }

  func refreshAuthorization() {
    center.getNotificationSettings { settings in
      let ok = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      Task { @MainActor in self.authorized = ok }
    }
  }

  func post(_ text: NotificationText, device: DeviceID) {
    let content = UNMutableNotificationContent()
    content.title = text.title
    content.body = text.body
    content.sound = .default
    content.categoryIdentifier = Self.categoryID
    content.userInfo = ["device": device.rawValue]
    center.add(UNNotificationRequest(identifier: text.identifier, content: content, trigger: nil))
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                          willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions
  {
    [.banner, .sound]
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                          didReceive response: UNNotificationResponse) async {
    let raw = response.notification.request.content.userInfo["device"] as? String
    let action = response.actionIdentifier
    await MainActor.run {
      switch action {
      case "snooze": if let raw { self.onSnooze?(DeviceID(raw)) }
      case "openOptions": OptionsPlus.open()
      default: SettingsWindowController.shared.show()
      }
    }
  }
}
