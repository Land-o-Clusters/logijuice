// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "logijuice-cli", targets: ["LogiJuiceCLI"]),
    .executable(name: "LogiJuiceWidgetExtension", targets: ["LogiJuiceWidgetExtension"]),
  ],
  targets: [
    .target(name: "JuiceCore"),
    .target(name: "JuiceStore", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "JuiceCLIKit", dependencies: ["JuiceCore", "JuiceStore", "JuiceHID"]),
    .target(name: "JuiceHID", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .executableTarget(name: "LogiJuiceCLI", dependencies: ["JuiceCLIKit", "JuiceStore"]),
    .executableTarget(
      name: "LogiJuiceWidgetExtension",
      dependencies: ["JuiceCore", "JuiceStore"],
      path: "WidgetExtension",
      exclude: ["Info.plist"],
      linkerSettings: [.linkedFramework("WidgetKit")]),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
    .testTarget(name: "JuiceStoreTests", dependencies: ["JuiceStore", "JuiceCore"]),
    .testTarget(name: "JuiceHIDTests", dependencies: ["JuiceHID", "JuiceCore"], resources: [.copy("Fixtures")]),
    .testTarget(name: "JuiceCLIKitTests", dependencies: ["JuiceCLIKit", "JuiceStore", "JuiceCore"]),
  ]
)
