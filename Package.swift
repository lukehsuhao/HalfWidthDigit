// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "HalfWidthDigit",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "HalfWidthDigit",
            path: "Sources"
        )
    ]
)
