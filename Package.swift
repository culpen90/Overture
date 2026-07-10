// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Overture",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Overture", targets: ["Overture"])
    ],
    targets: [
        .executableTarget(
            name: "Overture",
            path: "Sources/Overture"
        ),
        .testTarget(
            name: "OvertureTests",
            dependencies: ["Overture"],
            path: "Tests/OvertureTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
