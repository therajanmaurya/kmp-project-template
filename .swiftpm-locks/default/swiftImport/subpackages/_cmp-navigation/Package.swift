// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_cmp-navigation",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_cmp-navigation",
      type: .none,
      targets: ["_cmp-navigation"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_cmp-navigation",
      dependencies: [
      ]
    )
  ]
)
