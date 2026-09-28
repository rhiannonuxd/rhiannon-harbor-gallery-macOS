// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HarborGallery",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HarborGallery", targets: ["HarborGallery"])
    ],
    targets: [
        .executableTarget(
            name: "HarborGallery",
            path: "Sources/HarborGallery"
        )
    ]
)
