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
    platforms: [.macOS(.v15), .iOS(.v18)],
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
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.9.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        .target(
            name: "SwiftCLIKit"
        ),
        .target(
            name: "SwiftGUIKit",
            dependencies: ["SwiftCLIKit"]
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
            ]
        ),
        .executableTarget(
            name: "swiftclikit-examples",
            dependencies: ["SwiftCLIKit"],
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
            ]
        ),
        .testTarget(
            name: "SwiftGUIKitTests",
            dependencies: ["SwiftGUIKit", "SwiftCLIKit"]
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
