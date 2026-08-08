// swift-tools-version: 6.2
import PackageDescription

// Domain core for the sacrament meeting planner.
//
// macOS is a supported platform purely so `swift test` runs headless on a Mac — none of this
// package touches UIKit, SwiftUI, or SwiftData, so the whole Phase 1 domain layer is verifiable
// without a simulator or a signed build.
let package = Package(
    name: "PulpitKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PulpitKit", targets: ["PulpitKit"])
    ],
    targets: [
        .target(
            name: "PulpitKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PulpitKitTests",
            dependencies: ["PulpitKit"]
        ),
    ]
)
