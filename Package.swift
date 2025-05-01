// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardPreview",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.1"),
        .package(url: "https://github.com/johnxnguyen/Down.git", from: "0.11.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClipboardPreview",
            dependencies: [
                "SwiftSoup",
                "Down"
            ],
            path: "Sources"
        )
    ]
) 