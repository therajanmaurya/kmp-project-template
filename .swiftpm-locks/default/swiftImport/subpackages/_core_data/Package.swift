// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_core_data",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_core_data",
      type: .none,
      targets: ["_core_data"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_core_data",
      dependencies: [
      ]
    )
  ]
)
