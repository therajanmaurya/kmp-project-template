// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_rates",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_rates",
      type: .none,
      targets: ["_feature_rates"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_rates",
      dependencies: [
      ]
    )
  ]
)
