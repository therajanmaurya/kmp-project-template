// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_amortization",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_amortization",
      type: .none,
      targets: ["_feature_amortization"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_amortization",
      dependencies: [
      ]
    )
  ]
)
