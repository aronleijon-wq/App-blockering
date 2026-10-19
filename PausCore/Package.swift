// swift-tools-version:5.9
// The blocking logic shared by the app and its extensions, packaged so it can be tested with `swift test`.
// The Xcode project compiles the same sources directly into each target.
import PackageDescription

let package = Package(
    name: "PausCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "PausCore", targets: ["PausCore"]),
    ],
    targets: [
        .target(name: "PausCore"),
        .testTarget(name: "PausCoreTests", dependencies: ["PausCore"]),
    ]
)
