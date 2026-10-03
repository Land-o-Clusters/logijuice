import Foundation
import os
import ServiceManagement

enum LoginItem {
  static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

  static func set(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      Logger(subsystem: "com.penguinspecz.logijuice", category: "login")
        .error("login item change failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
