// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DigitalRoommate",
    platforms: [
        .macOS(.v14)  // Required for WKWebsiteDataStore(forIdentifier:)
    ],
    targets: [
        .executableTarget(
            name: "DigitalRoommate",
            path: "Sources/DigitalRoommate",
            resources: [
                .copy("../../Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)
