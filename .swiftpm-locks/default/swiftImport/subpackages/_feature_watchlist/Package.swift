// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_watchlist",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_watchlist",
      type: .none,
      targets: ["_feature_watchlist"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_watchlist",
      dependencies: [
      ]
    )
  ]
)
