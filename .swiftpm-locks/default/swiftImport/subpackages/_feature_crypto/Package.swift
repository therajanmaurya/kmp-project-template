// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_crypto",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_crypto",
      type: .none,
      targets: ["_feature_crypto"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_crypto",
      dependencies: [
      ]
    )
  ]
)
