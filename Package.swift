// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "emergency-stop",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),

        // 🍃 An expressive, performant, and extensible templating language built for Swift.
        .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),

        // 🧩 DynamoDB Database
        .package(url: "https://github.com/Yasumoto/fluent-dynamodb.git", .branch("master")),

        // 🔎 Better support for logging crashes
        .package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.0.2")
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentDynamoDB", "Leaf", "Backtrace", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
