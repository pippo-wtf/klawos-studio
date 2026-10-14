// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "KlawosStudio", platforms: [.macOS(.v14)],
    products: [.library(name: "KlawosContracts", targets: ["KlawosContracts"]),
               .executable(name: "KlawosProbe", targets: ["KlawosProbe"]),
               .executable(name: "KlawosStudio", targets: ["KlawosStudio"]),
               .executable(name: "KlawosAgent", targets: ["KlawosAgent"])],
    targets: [.target(name: "KlawosContracts"),
              .executableTarget(name: "KlawosProbe", dependencies: ["KlawosContracts"]),
              .executableTarget(name: "KlawosStudio", dependencies: ["KlawosContracts"]),
              .executableTarget(name: "KlawosAgent", dependencies: ["KlawosContracts"]),
              .testTarget(name: "KlawosTests", dependencies: ["KlawosContracts"])]
)
