// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "emergency-stop",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),

        // 🍃 An expressive, performant, and extensible templating language built for Swift.
        .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),

        // 🧩 DynamoDB Database
        //.package(url: "https://github.com/Yasumoto/fluent-dynamodb.git", from: "0.0.3"),
        .package(url: "https://github.com/Yasumoto/fluent-dynamodb", .branch("query-support")),

        // 🔎 Better support for logging crashes
        .package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.1.0"),

        // 🔥 Prometheus
        .package(url: "https://github.com/Yasumoto/SwiftPrometheus.git", from: "1.0.0-yasumoto.1"),

        // 📈 Metrics & Monitoring
        .package(url: "https://github.com/Yasumoto/VaporMonitoring.git", .branch("yasumoto-fork-the-things")),

    ],
    targets: [
        .target(name: "App", dependencies: [
            "Backtrace",
            "FluentDynamoDB",
            "Leaf",
            "SwiftPrometheus",
            "Vapor",
            "VaporMonitoring"
        ]),
        .target(name: "BootstrapDatabaseTool", dependencies: ["FluentDynamoDB"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
