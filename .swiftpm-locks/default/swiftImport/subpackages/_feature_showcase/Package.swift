// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_showcase",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_showcase",
      type: .none,
      targets: ["_feature_showcase"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_showcase",
      dependencies: [
      ]
    )
  ]
)
