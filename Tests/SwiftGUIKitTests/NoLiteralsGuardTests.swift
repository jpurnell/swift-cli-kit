// NoLiteralsGuardTests.swift
// SwiftGUIKit
//
// The "no literals in components" guardrail (design proposal §8.5), implemented
// as a dependency-free lexical scan. The scene-graph and projection layer —
// Node.swift and the *+Node.swift files — must speak semantic tokens
// (ColorRole / Symbol / TypeRole …), never literal colors, styles, or glyphs.
// The resolver (TerminalTokenResolver), the renderers (CellRenderer, the shared
// *Renderer helpers), and the SymbolSet definition ARE allowed literals — that
// is their job — so they are deliberately out of scope.

import Testing
import Foundation
import SwiftCLIKit

@Suite("No literals in the scene-graph / projection layer")
struct NoLiteralsGuardTests {

    /// `Sources/SwiftGUIKit`, located relative to this test file (robust to CWD).
    private var portableUIDir: URL {
        URL(fileURLWithPath: #filePath)     // …/Tests/SwiftGUIKitTests/NoLiteralsGuardTests.swift
            .deletingLastPathComponent()    // …/Tests/SwiftGUIKitTests
            .deletingLastPathComponent()    // …/Tests
            .deletingLastPathComponent()    // …/ (package root)
            .appendingPathComponent("Sources/SwiftGUIKit")
    }

    /// The in-scope files: the Node enum and every `.node()` projection.
    private var scopedFiles: [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: portableUIDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return items
            .filter { $0.lastPathComponent == "Node.swift" || $0.lastPathComponent.hasSuffix("+Node.swift") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Literal color/style constructs that must not appear in the scope.
    private let forbidden: [(pattern: String, why: String)] = [
        (".truecolor(", "literal Color — carry a ColorRole"),
        (".ansi8(", "literal Color — carry a ColorRole"),
        (".ansi256(", "literal Color — carry a ColorRole"),
        (".defaultColor", "literal Color — carry a ColorRole"),
        ("CellStyle(", "literal style — resolve it from a token in the renderer"),
        ("Color(", "literal Color — carry a ColorRole"),
    ]

    /// Removes `//` line comments and `/* … */` blocks so doc examples (which may
    /// legitimately mention glyphs or "Color") don't trip the scan.
    private func stripComments(_ source: String) -> String {
        var out = ""
        var inBlock = false
        for var line in source.lines {
            if inBlock {
                if let end = line.range(of: "*/") { line = String(line[end.upperBound...]); inBlock = false }
                else { continue }
            }
            while let start = line.range(of: "/*") {
                if let end = line.range(of: "*/", range: start.upperBound..<line.endIndex) {
                    line.replaceSubrange(start.lowerBound..<end.upperBound, with: " ")
                } else {
                    line = String(line[..<start.lowerBound]); inBlock = true; break
                }
            }
            if let slashes = line.range(of: "//") { line = String(line[..<slashes.lowerBound]) }
            out += line + "\n"
        }
        return out
    }

    @Test("scope resolves to real files")
    func scopeIsNonEmpty() {
        #expect(!scopedFiles.isEmpty, "guard found no files at \(portableUIDir.path) — check path resolution")
    }

    @Test("Node cases and .node() projections carry no literal colors or styles")
    func noColorOrStyleLiterals() throws {
        var violations: [String] = []
        for file in scopedFiles {
            let code = stripComments(try String(contentsOf: file, encoding: .utf8))
            for line in code.lines {
                for rule in forbidden where line.contains(rule.pattern) {
                    violations.append("\(file.lastPathComponent): '\(rule.pattern)' (\(rule.why)) → \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        for v in violations { Issue.record("literal color/style in scene-graph layer — \(v)") }
        #expect(violations.isEmpty)
    }

    @Test("Node cases and .node() projections carry no raw glyph literals")
    func noGlyphLiterals() throws {
        var violations: [String] = []
        for file in scopedFiles {
            let code = stripComments(try String(contentsOf: file, encoding: .utf8))
            for line in code.lines where line.unicodeScalars.contains(where: { !$0.isASCII }) {
                violations.append("\(file.lastPathComponent): non-ASCII glyph literal (glyphs come from the SymbolSet) → \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        for v in violations { Issue.record("glyph literal in scene-graph layer — \(v)") }
        #expect(violations.isEmpty)
    }

    @Test("self-check: the scan actually detects literals (has teeth)")
    func guardHasTeeth() {
        let badColor = "return .gauge(fill: CellStyle(fg: .truecolor(r: 1, g: 2, b: 3)))"
        #expect(forbidden.contains { stripComments(badColor).contains($0.pattern) })

        let badGlyph = "return .checkbox(mark: \"✓\")"
        #expect(stripComments(badGlyph).unicodeScalars.contains { !$0.isASCII })

        // And a comment mentioning a glyph or Color must NOT trip the scan.
        let okComment = "/// Renders [✓] using Color roles like .truecolor examples."
        let stripped = stripComments(okComment)
        #expect(!forbidden.contains { stripped.contains($0.pattern) })
        #expect(!stripped.unicodeScalars.contains { !$0.isASCII })
    }
}
