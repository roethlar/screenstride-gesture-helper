// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ScreenStrideGestureHelper",
    platforms: [.macOS("14.0")],
    products: [.library(name: "GestureHelperCore", targets: ["GestureHelperCore"])],
    targets: [
        .target(name: "GestureHelperCore"),
        .testTarget(name: "GestureHelperCoreTests", dependencies: ["GestureHelperCore"])
    ]
)
