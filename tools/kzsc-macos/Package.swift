// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KZSCMacOS",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "KZSCMacOS", targets: ["KZSCMacOS"])],
    targets: [.executableTarget(name: "KZSCMacOS")]
)
