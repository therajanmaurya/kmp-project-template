// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_core_ui",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_core_ui",
      type: .none,
      targets: ["_core_ui"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_core_ui",
      dependencies: [
      ]
    )
  ]
)
