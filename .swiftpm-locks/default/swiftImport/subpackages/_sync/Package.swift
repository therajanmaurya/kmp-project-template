// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_sync",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_sync",
      type: .none,
      targets: ["_sync"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_sync",
      dependencies: [
      ]
    )
  ]
)
