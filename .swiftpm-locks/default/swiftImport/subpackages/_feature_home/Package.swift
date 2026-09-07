// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_home",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_home",
      type: .none,
      targets: ["_feature_home"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_home",
      dependencies: [
      ]
    )
  ]
)
