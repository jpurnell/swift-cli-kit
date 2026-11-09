// swift-tools-version: 6.2
// legibility:description: Pure Swift terminal abstraction library -- raw mode, input parsing, line editing, and rendering primitives with zero C dependencies.
// Floor tracks CI (quality-gate-reusable.yml pins 6.2), per ADR-014.
// Was pinned to 6.0 for a deployment target whose toolchain has since moved on, so
// the pin's reason expired. Re-verify the deploy target before lowering this again.
//
//  Package.swift
//  SwiftCLIKit
//
//  Created by Justin Purnell on 2026-04-10.
//

import PackageDescription

let package = Package(
    name: "SwiftCLIKit",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1), .watchOS(.v10), .tvOS(.v17)],
    products: [
        .library(name: "SwiftCLIKit", targets: ["SwiftCLIKit"]),
        .library(name: "SwiftCLIKitSSH", targets: ["SwiftCLIKitSSH"]),
        .library(name: "SwiftGUIKit", targets: ["SwiftGUIKit"]),
        .library(name: "SwiftGUIKitSwiftUI", targets: ["SwiftGUIKitSwiftUI"]),
        .library(name: "QualityGateDashboard", targets: ["QualityGateDashboard"]),
        .executable(name: "qg-dashboard", targets: ["qg-dashboard"]),
        .executable(name: "QGDashboardApp", targets: ["QGDashboardApp"]),
        .executable(name: "swiftclikit-examples", targets: ["swiftclikit-examples"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.15.0"),
        // Already in the graph through swift-nio. Named here only for the examples target,
        // whose SIGINT handler needs a flag that is safe to set from a signal handler — a
        // lock is not. No library product links it.
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
        // Already in the graph through swift-nio-ssh, whose key types are Crypto's. Named here so
        // SwiftCLIKitSSH can build an `NIOSSHPrivateKey` from a host key file; nothing new is
        // resolved or linked. The range is swift-nio-ssh's own.
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"5.0.0"),
        // The design system's values as Foundation-only data (expected to build on Linux, untested). SwiftGUIKit's
        // terminal resolver reads the accent from it, so one accent decision reaches every surface.
        // Public repository, fetched over HTTPS like the rest of the fleet.
        .package(url: "https://github.com/jpurnell/DesignTokens.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftCLIKit"
        ),
        .target(
            name: "SwiftGUIKit",
            dependencies: [
                "SwiftCLIKit",
                .product(name: "DesignTokens", package: "DesignTokens"),
            ]
        ),
        .target(
            name: "SwiftGUIKitSwiftUI",
            dependencies: ["SwiftGUIKit", "SwiftCLIKit"]
        ),
        .target(
            name: "QualityGateDashboard",
            dependencies: ["SwiftGUIKit", "SwiftCLIKit"]
        ),
        .executableTarget(
            name: "qg-dashboard",
            dependencies: ["QualityGateDashboard", "SwiftCLIKit"]
        ),
        .executableTarget(
            name: "QGDashboardApp",
            dependencies: ["QualityGateDashboard", "SwiftCLIKit", "SwiftGUIKit", "SwiftGUIKitSwiftUI"]
        ),
        .target(
            name: "SwiftCLIKitSSH",
            dependencies: [
                "SwiftCLIKit",
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .executableTarget(
            name: "swiftclikit-examples",
            dependencies: [
                "SwiftCLIKit",
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            path: "Sources/swiftclikit-examples"
        ),
        .testTarget(
            name: "SwiftCLIKitTests",
            dependencies: ["SwiftCLIKit"]
        ),
        .testTarget(
            name: "SwiftCLIKitSSHTests",
            dependencies: [
                "SwiftCLIKitSSH",
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "SwiftGUIKitTests",
            dependencies: [
                "SwiftGUIKit", "SwiftCLIKit",
                .product(name: "DesignTokens", package: "DesignTokens"),
            ]
        ),
        .testTarget(
            name: "SwiftGUIKitSwiftUITests",
            dependencies: ["SwiftGUIKitSwiftUI", "SwiftGUIKit"]
        ),
        .testTarget(
            name: "QualityGateDashboardTests",
            dependencies: ["QualityGateDashboard", "SwiftGUIKit", "SwiftCLIKit", "SwiftGUIKitSwiftUI"]
        ),
    ]
)
