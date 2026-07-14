// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TCPV4MACCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TCPV4MACCore", targets: ["TCPV4MACCore"]),
        .executable(name: "tcpv4mac-cli", targets: ["tcpv4mac-cli"])
    ],
    targets: [
        .target(
            name: "TCPV4MACCore"
        ),
        .executableTarget(
            name: "tcpv4mac-cli",
            dependencies: ["TCPV4MACCore"]
        ),
        .testTarget(
            name: "TCPV4MACCoreTests",
            dependencies: ["TCPV4MACCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
