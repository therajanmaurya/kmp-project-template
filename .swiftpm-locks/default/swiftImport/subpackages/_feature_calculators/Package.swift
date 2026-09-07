// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_calculators",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_calculators",
      type: .none,
      targets: ["_feature_calculators"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_calculators",
      dependencies: [
      ]
    )
  ]
)
