// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_profile",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_profile",
      type: .none,
      targets: ["_feature_profile"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_profile",
      dependencies: [
      ]
    )
  ]
)
