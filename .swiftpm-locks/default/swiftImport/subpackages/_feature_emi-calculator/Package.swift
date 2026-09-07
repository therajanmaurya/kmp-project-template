// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_emi-calculator",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_emi-calculator",
      type: .none,
      targets: ["_feature_emi-calculator"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_emi-calculator",
      dependencies: [
      ]
    )
  ]
)
