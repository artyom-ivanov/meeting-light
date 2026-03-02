// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeetingLight",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MeetingLight",
            path: "Sources/MeetingLight",
            exclude: ["AppIcon.png"],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
