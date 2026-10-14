// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "KlawosStudio", platforms: [.macOS(.v14)],
    products: [.library(name: "KlawosContracts", targets: ["KlawosContracts"]),
               .executable(name: "KlawosProbe", targets: ["KlawosProbe"])],
    targets: [.target(name: "KlawosContracts"),
              .executableTarget(name: "KlawosProbe", dependencies: ["KlawosContracts"]),
              .testTarget(name: "KlawosTests", dependencies: ["KlawosContracts"])]
)
