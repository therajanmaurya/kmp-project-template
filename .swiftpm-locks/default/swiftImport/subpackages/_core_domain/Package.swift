// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_core_domain",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_core_domain",
      type: .none,
      targets: ["_core_domain"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_core_domain",
      dependencies: [
      ]
    )
  ]
)
