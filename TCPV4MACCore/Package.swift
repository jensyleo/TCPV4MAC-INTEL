// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TCPV4MACCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TCPV4MACCore", targets: ["TCPV4MACCore"]),
        .executable(name: "tcpv4mac-cli", targets: ["tcpv4mac-cli"])
    ],
    targets: [
        .target(
            name: "TCPV4MACCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "tcpv4mac-cli",
            dependencies: ["TCPV4MACCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "TCPV4MACCoreTests",
            dependencies: ["TCPV4MACCore"],
            resources: [
                .process("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
