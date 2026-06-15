// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lexed",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Lexed", targets: ["Lexed"])
    ],
    targets: [
        .executableTarget(
            name: "Lexed",
            path: "Sources/Lexed",
            exclude: ["Info.plist", "Lexed.entitlements"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                // Embed Info.plist so the binary carries the TCC usage-description
                // strings even when launched directly (without an .app bundle).
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Lexed/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "LexedTests",
            dependencies: ["Lexed"],
            path: "Tests/LexedTests"
        )
    ]
)
