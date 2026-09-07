// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_feature_add-to-watchlist",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_feature_add-to-watchlist",
      type: .none,
      targets: ["_feature_add-to-watchlist"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_feature_add-to-watchlist",
      dependencies: [
      ]
    )
  ]
)
