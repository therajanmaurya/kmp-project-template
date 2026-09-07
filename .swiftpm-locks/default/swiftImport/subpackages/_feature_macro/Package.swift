// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_macro",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_macro",
      type: .none,
      targets: ["_feature_macro"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_macro",
      dependencies: [
      ]
    )
  ]
)
