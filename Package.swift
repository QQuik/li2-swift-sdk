// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Li2SDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Li2SDK", targets: ["Li2SDK"])
    ],
    targets: [
        // Module is `Li2SDK` (not `Li2`): a consumer app target named `li2`
        // case-collides with a `Li2` module on macOS's case-insensitive
        // filesystem, corrupting DerivedData (Li2.build == li2.build). The
        // public facade TYPE stays `Li2` — `import Li2SDK` then `Li2.configure`.
        //
        // swift-tools-version 6.0 already makes Swift 6 language mode (full
        // strict concurrency) the default for every target — no per-target
        // .swiftLanguageMode needed (it tripped an 'unavailable' manifest error
        // in Xcode's resolver; the tools-version default is equivalent).
        .target(
            name: "Li2SDK",
            path: "Sources/Li2SDK"
        ),
        .testTarget(
            name: "Li2SDKTests",
            dependencies: ["Li2SDK"],
            path: "Tests/Li2SDKTests"
        )
    ]
)
