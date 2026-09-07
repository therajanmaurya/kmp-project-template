// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "_cmp-shared",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "_cmp-shared",
      type: .none,
      targets: ["_cmp-shared"]
    )
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "_cmp-shared",
      dependencies: [
      ]
    )
  ]
)
