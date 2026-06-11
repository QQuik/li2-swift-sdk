// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Li2",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Li2", targets: ["Li2"])
    ],
    targets: [
        .target(
            name: "Li2",
            path: "Sources/Li2"
        ),
        .testTarget(
            name: "Li2Tests",
            dependencies: ["Li2"],
            path: "Tests/Li2Tests"
        )
    ]
)
