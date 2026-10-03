// swift-tools-version: 5.10
import Foundation
import PackageDescription

/// Absolute repo root, for compiler flags that need a file path (App Intents constant extraction).
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "LogiJuice", targets: ["LogiJuice"]),
    .executable(name: "LogiJuiceWidgetExtension", targets: ["LogiJuiceWidgetExtension"]),
    .executable(name: "logijuice-cli", targets: ["LogiJuiceCLI"]),
  ],
  targets: [
    .target(name: "JuiceCore"),
    .target(name: "JuiceStore", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "JuiceHID", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "JuiceCLIKit", dependencies: ["JuiceCore", "JuiceStore", "JuiceHID"]),
    .executableTarget(name: "LogiJuiceCLI", dependencies: ["JuiceCLIKit", "JuiceStore"]),
    .executableTarget(
      name: "LogiJuice",
      dependencies: ["JuiceCore", "JuiceStore", "JuiceHID"],
      path: "App",
      swiftSettings: [
        // Lets scripts/build-app.sh compile App Intents metadata (Xcode does this automatically).
        .unsafeFlags(["-emit-const-values-path", "\(root)/.build/LogiJuice.swiftconstvalues",
                      "-Xfrontend", "-const-gather-protocols-file",
                      "-Xfrontend", "\(root)/Config/const_extract_protocols.json"],
                     .when(configuration: .release)),
      ],
      linkerSettings: [
        .linkedFramework("WidgetKit"), .linkedFramework("ServiceManagement"),
        .linkedFramework("UserNotifications"), .linkedFramework("AppIntents"),
      ]),
    .executableTarget(
      name: "LogiJuiceWidgetExtension",
      dependencies: ["JuiceCore", "JuiceStore"],
      path: "WidgetExtension",
      exclude: ["Info.plist"],
      linkerSettings: [
        .linkedFramework("WidgetKit"),
        // App extensions must enter via _NSExtensionMain, as Xcode links them; see scripts/build-app.sh.
        .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"]),
      ]),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
    .testTarget(name: "JuiceStoreTests", dependencies: ["JuiceStore", "JuiceCore"]),
    .testTarget(name: "JuiceCLIKitTests", dependencies: ["JuiceCLIKit", "JuiceStore", "JuiceCore"]),
    .testTarget(name: "JuiceHIDTests", dependencies: ["JuiceHID", "JuiceCore"], resources: [.copy("Fixtures")]),
  ]
)
