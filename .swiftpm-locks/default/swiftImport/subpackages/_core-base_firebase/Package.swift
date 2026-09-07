// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_core-base_firebase",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_core-base_firebase",
      type: .none,
      targets: ["_core-base_firebase"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_core-base_firebase",
      dependencies: [
      ]
    )
  ]
)
