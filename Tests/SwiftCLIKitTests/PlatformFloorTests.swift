// PlatformFloorTests.swift
// SwiftCLIKit

import Testing
import Foundation

/// Reads the two things the platform floor depends on: what the manifest declares, and
/// what the sources import.
enum PlatformFloorScan {
    /// The first macOS release that ships the `Synchronization` module.
    static let synchronizationMinimumMacOS = 15

    /// The major version in the manifest's `.macOS(.vNN)` or `.macOS("NN…")`, or `nil` if
    /// the manifest declares no macOS floor this can read.
    static func declaredMacOSFloor(manifest: String) -> Int? {
        for line in manifest.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let code = stripLineComment(String(line))
            guard let range = code.range(of: ".macOS(") else { continue }
            let digits = code[range.upperBound...]
                .drop(while: { !$0.isNumber })
                .prefix(while: { $0.isNumber })
            guard let major = Int(digits) else { continue }
            return major
        }
        return nil
    }

    /// One-based line numbers on which `source` imports `Synchronization`.
    ///
    /// Matches the import however it is spelled — attributed, access-modified, or scoped
    /// to a single declaration — and ignores a mention in a comment.
    static func synchronizationImportLines(in source: String) -> [Int] {
        var hits: [Int] = []
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for (index, line) in lines.enumerated() {
            let words = stripLineComment(String(line))
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            guard let importIndex = words.firstIndex(of: "import") else { continue }
            let prefixIsModifiers = words[..<importIndex].allSatisfy { word in
                word.hasPrefix("@") || accessModifiers.contains(word)
            }
            guard prefixIsModifiers else { continue }
            let imported = words[(importIndex + 1)...]
            let module = imported.first { !importKinds.contains($0) } ?? ""
            let root = module.split(separator: ".").first.map(String.init) ?? ""
            if root == "Synchronization" {
                hits.append(index + 1)
            }
        }
        return hits
    }

    /// Every `.swift` file under `directory`, as paths relative to it, sorted.
    static func swiftFiles(under directory: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        var found: [String] = []
        let base = directory.resolvingSymlinksInPath().pathComponents
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let components = url.resolvingSymlinksInPath().pathComponents
            guard components.starts(with: base) else { continue }
            found.append(components.dropFirst(base.count).joined(separator: "/"))
        }
        return found.sorted()
    }

    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)     // …/Tests/SwiftCLIKitTests/PlatformFloorTests.swift
            .deletingLastPathComponent()    // …/Tests/SwiftCLIKitTests
            .deletingLastPathComponent()    // …/Tests
            .deletingLastPathComponent()    // package root
    }

    private static let accessModifiers: Set<String> = [
        "public", "package", "internal", "fileprivate", "private",
    ]

    private static let importKinds: Set<String> = [
        "struct", "class", "enum", "protocol", "typealias", "func", "let", "var",
    ]

    private static func stripLineComment(_ line: String) -> String {
        guard let range = line.range(of: "//") else { return line }
        return String(line[..<range.lowerBound])
    }
}

/// The macOS floor is 14 because the deployment host cannot go higher, and
/// `Synchronization` is the module that silently raises it: the package still compiles
/// on a newer machine, and the binary dies at launch on the host looking for
/// `libswiftSynchronization.dylib`.
@Suite("Platform floor")
struct PlatformFloorTests {

    // MARK: - Reading the manifest

    @Test("Reads an enum-style macOS floor")
    func readsEnumFloor() {
        let manifest = """
            let package = Package(
                name: "X",
                platforms: [.macOS(.v14), .iOS(.v17)],
            """
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: manifest) == 14)
    }

    @Test("Reads a string-style macOS floor")
    func readsStringFloor() {
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: #"platforms: [.macOS("15.4")]"#) == 15)
    }

    @Test("Reads an old underscore-style floor by its major version")
    func readsUnderscoreFloor() {
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: "platforms: [.macOS(.v10_15)]") == 10)
    }

    @Test("A commented-out floor is not the floor")
    func ignoresCommentedFloor() {
        let manifest = """
            // platforms: [.macOS(.v15)],
            platforms: [.macOS(.v14)],
            """
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: manifest) == 14)
    }

    @Test("A manifest with no macOS floor reads as nil")
    func missingFloorIsNil() {
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: "platforms: [.iOS(.v17)]") == nil)
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: "") == nil)
    }

    // MARK: - Finding the import

    @Test("Finds a plain import and reports its line")
    func findsPlainImport() {
        let source = """
            import Foundation
            import Synchronization

            let x = 1
            """
        #expect(PlatformFloorScan.synchronizationImportLines(in: source) == [2])
    }

    @Test(
        "Finds the import however it is spelled",
        arguments: [
            "    import Synchronization",
            "@preconcurrency import Synchronization",
            "internal import Synchronization",
            "@_implementationOnly private import Synchronization",
            "import struct Synchronization.Mutex",
            "import Synchronization // for Mutex",
            "import\tSynchronization",
        ]
    )
    func findsSpelledImport(line: String) {
        #expect(PlatformFloorScan.synchronizationImportLines(in: line) == [1])
    }

    @Test(
        "Does not mistake something else for the import",
        arguments: [
            "// import Synchronization",
            "/// Replaces `import Synchronization`.",
            "import SynchronizationShims",
            "import Foundation",
            "let note = \"import Synchronization\"",
            "let important = Synchronization.self",
            "",
        ]
    )
    func ignoresNonImport(line: String) {
        #expect(PlatformFloorScan.synchronizationImportLines(in: line) == [])
    }

    @Test("Counts lines the same way in a CRLF file")
    func findsImportInCRLFSource() {
        let source = "import Foundation\r\nimport Synchronization\r\n\r\nimport Synchronization\r\n"
        #expect(PlatformFloorScan.synchronizationImportLines(in: source) == [2, 4])
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: "let x = 1\r\nplatforms: [.macOS(.v14)],\r\n") == 14)
    }

    @Test("Reports every import in a file")
    func findsEveryImport() {
        let source = """
            #if canImport(os)
            import os
            #else
            import Synchronization
            #endif
            import Synchronization
            """
        #expect(PlatformFloorScan.synchronizationImportLines(in: source) == [4, 6])
    }

    // MARK: - The package itself

    @Test("The manifest declares macOS 14")
    func manifestDeclaresMacOS14() throws {
        let manifest = try String(
            contentsOf: PlatformFloorScan.packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        #expect(PlatformFloorScan.declaredMacOSFloor(manifest: manifest) == 14)
    }

    @Test("The scan sees the sources it is meant to guard")
    func scanReachesSources() {
        let files = PlatformFloorScan.swiftFiles(
            under: PlatformFloorScan.packageRoot.appendingPathComponent("Sources")
        )
        // A scan that found nothing would pass the guard below for the wrong reason.
        #expect(files.contains("SwiftCLIKit/Util/LockedState.swift"))
        #expect(files.contains("SwiftCLIKitSSH/SSHBackend.swift"))
        #expect(files.contains("swiftclikit-examples/04_LiveDashboard.swift"))
    }

    @Test("No source imports Synchronization while the macOS floor is below 15")
    func noSynchronizationBelowItsFloor() throws {
        let root = PlatformFloorScan.packageRoot
        let manifest = try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)
        let floor = try #require(
            PlatformFloorScan.declaredMacOSFloor(manifest: manifest),
            "Package.swift declares no macOS floor this test can read"
        )
        guard floor < PlatformFloorScan.synchronizationMinimumMacOS else { return }

        let sources = root.appendingPathComponent("Sources")
        var offenders: [String] = []
        for relativePath in PlatformFloorScan.swiftFiles(under: sources) {
            let source = try String(contentsOf: sources.appendingPathComponent(relativePath), encoding: .utf8)
            for line in PlatformFloorScan.synchronizationImportLines(in: source) {
                offenders.append("Sources/\(relativePath):\(line)")
            }
        }
        #expect(
            offenders == [],
            "Synchronization needs macOS 15; the declared floor is macOS \(floor). Use LockedState."
        )
    }
}
