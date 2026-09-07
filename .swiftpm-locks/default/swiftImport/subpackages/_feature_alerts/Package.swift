// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_alerts",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_alerts",
      type: .none,
      targets: ["_feature_alerts"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_alerts",
      dependencies: [
      ]
    )
  ]
)
