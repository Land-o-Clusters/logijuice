import Foundation
import IOKit

public enum MacIdentity {
  public static func hardwareUUID() -> String {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    defer { IOObjectRelease(service) }
    let value = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue() as? String
    return value ?? "unknown-\(ProcessInfo.processInfo.hostName)"
  }

  public static func name() -> String { Host.current().localizedName ?? "Mac" }
}
