// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "nx_opus_macos",
    platforms: [.macOS("10.15")],
    products: [.library(name: "nx-opus-macos", targets: ["nx_opus_macos"])],
    targets: [
        .binaryTarget(name: "opus", path: "opus.xcframework"),
        .target(name: "nx_opus_macos", dependencies: ["opus"])
    ]
)
