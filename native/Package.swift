// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "KlawosStudio", platforms: [.macOS(.v14)],
    products: [.library(name: "KlawosContracts", targets: ["KlawosContracts"])],
    targets: [.target(name: "KlawosContracts"),
              .testTarget(name: "KlawosTests", dependencies: ["KlawosContracts"])]
)
