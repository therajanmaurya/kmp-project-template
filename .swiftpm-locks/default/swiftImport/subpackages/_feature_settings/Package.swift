// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_settings",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_settings",
      type: .none,
      targets: ["_feature_settings"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_settings",
      dependencies: [
      ]
    )
  ]
)
