// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Li2",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Li2", targets: ["Li2"])
    ],
    targets: [
        .target(
            name: "Li2",
            path: "Sources/Li2",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "Li2Tests",
            dependencies: ["Li2"],
            path: "Tests/Li2Tests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
