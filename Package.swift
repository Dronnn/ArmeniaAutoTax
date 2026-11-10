// swift-tools-version: 5.9
import PackageDescription

// Independent pure-Swift test harness. The iOS app compiles the same Core sources.
let package = Package(
    name: "ArmeniaAutoTaxCore",
    platforms: [.iOS(.v17)],
    products: [.library(name: "TaxCore", targets: ["TaxCore"])],
    targets: [
        .target(name: "TaxCore", path: "ArmeniaAutoTax/Core"),
        .testTarget(name: "TaxCoreTests", dependencies: ["TaxCore"], path: "Tests/TaxCoreTests")
    ]
)
