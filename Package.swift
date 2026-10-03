// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "JuiceCore"),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
  ]
)
