// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ForeignAffairsReader",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ForeignAffairsReader", targets: ["ForeignAffairsReader"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ForeignAffairsReader",
            dependencies: [],
            path: "Sources",
            exclude: ["Info.plist", "WebView.swift"]
        )
    ],
    swiftLanguageModes: [.v6]
)
