// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LogiBatteryKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LogiBatteryKit", targets: ["LogiBatteryKit"]),
        .executable(name: "logi-battery", targets: ["logi-battery"]),
    ],
    targets: [
        .target(name: "LogiBatteryKit"),
        .executableTarget(name: "logi-battery", dependencies: ["LogiBatteryKit"]),
        .testTarget(name: "LogiBatteryKitTests", dependencies: ["LogiBatteryKit"]),
    ],
    swiftLanguageModes: [.v5]
)
