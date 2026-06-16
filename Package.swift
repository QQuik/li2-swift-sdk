// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Li2",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Li2", targets: ["Li2"])
    ],
    targets: [
        // swift-tools-version 6.0 already makes Swift 6 language mode (full
        // strict concurrency) the default for every target — no per-target
        // .swiftLanguageMode needed. Declaring it explicitly tripped an
        // 'unavailable' manifest error in Xcode's resolver; the tools-version
        // default is equivalent and portable.
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
