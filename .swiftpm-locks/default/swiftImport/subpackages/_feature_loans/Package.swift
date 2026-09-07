// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_loans",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_loans",
      type: .none,
      targets: ["_feature_loans"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_loans",
      dependencies: [
      ]
    )
  ]
)
