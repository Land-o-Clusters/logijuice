// swift-tools-version: 5.10
import PackageDescription

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
      linkerSettings: [
        .linkedFramework("WidgetKit"), .linkedFramework("ServiceManagement"),
        .linkedFramework("UserNotifications"),
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
