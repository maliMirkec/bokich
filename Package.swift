// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "Bokich",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "Bokich",
      path: "Sources/Bokich"
    )
  ]
)
