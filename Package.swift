// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SpeakEase",
    platforms: [.macOS(.v26)],
    products: [
        .executable(
            name: "SpeakEase",
            targets: ["SpeakEase"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SpeakEase",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("FoundationModels"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "SpeakEaseTests",
            dependencies: ["SpeakEase"],
            path: "Tests/SpeakEaseTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
