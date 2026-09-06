// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "TubitakJnlpGuard",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "TubitakJnlpCore", targets: ["TubitakJnlpCore"]),
    .executable(name: "TubitakJnlpGuard", targets: ["TubitakJnlpGuard"]),
  ],
  targets: [
    .target(name: "TubitakJnlpCore"),
    .executableTarget(
      name: "TubitakJnlpGuard",
      dependencies: ["TubitakJnlpCore"]
    ),
    .testTarget(
      name: "TubitakJnlpCoreTests",
      dependencies: ["TubitakJnlpCore"]
    ),
  ]
)
