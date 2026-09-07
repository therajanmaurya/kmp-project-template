// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "KotlinMultiplatformLinkedPackage",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "KotlinMultiplatformLinkedPackage",
      type: .none,
      targets: ["KotlinMultiplatformLinkedPackage"]
    )
  ],
  dependencies: [
    .package(path: "subpackages/_cmp-navigation"),
    .package(path: "subpackages/_cmp-shared"),
    .package(path: "subpackages/_core-base_firebase"),
    .package(path: "subpackages/_core_data"),
    .package(path: "subpackages/_core_domain"),
    .package(path: "subpackages/_core_firebase"),
    .package(path: "subpackages/_core_ui"),
    .package(path: "subpackages/_feature_add-to-watchlist"),
    .package(path: "subpackages/_feature_alerts"),
    .package(path: "subpackages/_feature_amortization"),
    .package(path: "subpackages/_feature_bills"),
    .package(path: "subpackages/_feature_calculators"),
    .package(path: "subpackages/_feature_cloudtodo"),
    .package(path: "subpackages/_feature_crypto"),
    .package(path: "subpackages/_feature_currency-rates"),
    .package(path: "subpackages/_feature_emi-calculator"),
    .package(path: "subpackages/_feature_home"),
    .package(path: "subpackages/_feature_loans"),
    .package(path: "subpackages/_feature_macro"),
    .package(path: "subpackages/_feature_profile"),
    .package(path: "subpackages/_feature_rates"),
    .package(path: "subpackages/_feature_settings"),
    .package(path: "subpackages/_feature_showcase"),
    .package(path: "subpackages/_feature_watchlist"),
    .package(path: "subpackages/_sync"),
    .package(path: "subpackages/dev_gitlive_firebase_analytics_3_0_0_alpha01"),
    .package(path: "subpackages/dev_gitlive_firebase_app_3_0_0_alpha01"),
    .package(path: "subpackages/dev_gitlive_firebase_crashlytics_3_0_0_alpha01")
  ],
  targets: [
    .target(
      name: "KotlinMultiplatformLinkedPackage",
      dependencies: [
        .product(name: "_cmp-navigation", package: "_cmp-navigation"),
        .product(name: "_cmp-shared", package: "_cmp-shared"),
        .product(name: "_core-base_firebase", package: "_core-base_firebase"),
        .product(name: "_core_data", package: "_core_data"),
        .product(name: "_core_domain", package: "_core_domain"),
        .product(name: "_core_firebase", package: "_core_firebase"),
        .product(name: "_core_ui", package: "_core_ui"),
        .product(name: "_feature_add-to-watchlist", package: "_feature_add-to-watchlist"),
        .product(name: "_feature_alerts", package: "_feature_alerts"),
        .product(name: "_feature_amortization", package: "_feature_amortization"),
        .product(name: "_feature_bills", package: "_feature_bills"),
        .product(name: "_feature_calculators", package: "_feature_calculators"),
        .product(name: "_feature_cloudtodo", package: "_feature_cloudtodo"),
        .product(name: "_feature_crypto", package: "_feature_crypto"),
        .product(name: "_feature_currency-rates", package: "_feature_currency-rates"),
        .product(name: "_feature_emi-calculator", package: "_feature_emi-calculator"),
        .product(name: "_feature_home", package: "_feature_home"),
        .product(name: "_feature_loans", package: "_feature_loans"),
        .product(name: "_feature_macro", package: "_feature_macro"),
        .product(name: "_feature_profile", package: "_feature_profile"),
        .product(name: "_feature_rates", package: "_feature_rates"),
        .product(name: "_feature_settings", package: "_feature_settings"),
        .product(name: "_feature_showcase", package: "_feature_showcase"),
        .product(name: "_feature_watchlist", package: "_feature_watchlist"),
        .product(name: "_sync", package: "_sync"),
        .product(name: "dev_gitlive_firebase_analytics_3_0_0_alpha01", package: "dev_gitlive_firebase_analytics_3_0_0_alpha01"),
        .product(name: "dev_gitlive_firebase_app_3_0_0_alpha01", package: "dev_gitlive_firebase_app_3_0_0_alpha01"),
        .product(name: "dev_gitlive_firebase_crashlytics_3_0_0_alpha01", package: "dev_gitlive_firebase_crashlytics_3_0_0_alpha01")
      ]
    )
  ]
)
