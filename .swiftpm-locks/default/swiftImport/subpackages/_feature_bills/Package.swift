// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_bills",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_bills",
      type: .none,
      targets: ["_feature_bills"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_bills",
      dependencies: [
      ]
    )
  ]
)
