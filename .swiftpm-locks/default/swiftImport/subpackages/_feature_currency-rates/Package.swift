// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_currency-rates",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_currency-rates",
      type: .none,
      targets: ["_feature_currency-rates"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_currency-rates",
      dependencies: [
      ]
    )
  ]
)
