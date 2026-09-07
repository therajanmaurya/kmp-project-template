// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_cloudtodo",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_cloudtodo",
      type: .none,
      targets: ["_feature_cloudtodo"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_cloudtodo",
      dependencies: [
      ]
    )
  ]
)
