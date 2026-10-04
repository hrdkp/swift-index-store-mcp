// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IndexStoreMCP",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "index-store-mcp", targets: ["IndexStoreMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        .package(url: "https://github.com/swiftlang/indexstore-db", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "IndexStoreMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "IndexStoreDB", package: "indexstore-db"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/IndexStoreMCP"
        ),
        .testTarget(
            name: "IndexStoreMCPTests",
            dependencies: [
                "IndexStoreMCP",
                .product(name: "IndexStoreDB", package: "indexstore-db"),
            ]
        ),
    ]
)
