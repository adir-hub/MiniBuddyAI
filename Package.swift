// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiniBuddyAI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MiniBuddyAI", targets: ["MiniBuddyAI"])
    ],
    targets: [
        .executableTarget(
            name: "MiniBuddyAI",
            path: "Sources/MiniBuddyAI"
        )
    ]
)
