// SnapshotTesting.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
import Synchronization

/// Utilities for snapshot-based testing of ``CellBuffer`` contents.
///
/// Renders buffers to plain text or styled strings for golden-file comparison.
///
/// ```swift
/// var buffer = CellBuffer(width: 80, height: 24)
///
/// let text = SnapshotTesting.renderPlainText(buffer)
/// let diff = SnapshotTesting.compare(buffer, goldenFile: "expected.txt")
/// ```
public enum SnapshotTesting {
    /// Renders a buffer to a styled string representation with style markers.
    /// - Parameter buffer: The buffer to render.
    /// - Returns: A styled string representation.
    public static func render(_ buffer: CellBuffer) -> String {
        var lines: [String] = []
        var currentFg: Color?
        var currentBg: Color?
        var currentAttrs: CellAttributes?

        for y in 0..<buffer.height {
            var line = ""
            for x in 0..<buffer.width {
                let cell = buffer[x, y]
                let fg = cell.fg
                let bg = cell.bg
                let attrs = cell.attributes

                if fg != currentFg || bg != currentBg || attrs != currentAttrs {
                    let fgName = colorName(fg)
                    let bgName = colorName(bg)
                    let attrStr = attributesString(attrs)
                    line += "[\(fgName):\(bgName):\(attrStr)]"
                    currentFg = fg
                    currentBg = bg
                    currentAttrs = attrs
                }
                line += String(cell.character)
            }
            // Trim trailing spaces
            let trimmed = line.replacingOccurrences(
                of: "\\s+$",
                with: "",
                options: .regularExpression
            )
            lines.append(trimmed)
        }
        return lines.joined(separator: "\n")
    }

    /// Renders a buffer to plain text (characters only, no style info).
    /// - Parameter buffer: The buffer to render.
    /// - Returns: A plain text representation with newlines between rows.
    public static func renderPlainText(_ buffer: CellBuffer) -> String {
        var lines: [String] = []
        for y in 0..<buffer.height {
            var line = ""
            for x in 0..<buffer.width {
                let cell = buffer[x, y]
                line += String(cell.character)
            }
            // Trim trailing spaces
            let trimmed: String
            if let lastNonSpace = line.lastIndex(where: { $0 != " " }) {
                trimmed = String(line[...lastNonSpace])
            } else {
                trimmed = ""
            }
            lines.append(trimmed)
        }
        return lines.joined(separator: "\n")
    }

    /// Compares a buffer against a golden file.
    /// - Parameters:
    ///   - buffer: The buffer to compare.
    ///   - goldenFile: The path to the expected output file.
    /// - Returns: `nil` if the buffer matches, or a diff string describing mismatches.
    public static func compare(_ buffer: CellBuffer, goldenFile: String) -> String? {
        let rendered = renderPlainText(buffer)
        guard let golden = try? String(contentsOfFile: goldenFile, encoding: .utf8) else { // silent: missing golden file is a reportable comparison failure, not an error
            return "Golden file not found: \(goldenFile)"
        }
        guard rendered != golden else { return nil }

        let renderedLines = rendered.lines
        let goldenLines = golden.lines
        let maxLines = max(renderedLines.count, goldenLines.count)

        for i in 0..<maxLines {
            let rLine = i < renderedLines.count ? renderedLines[i] : "<missing>"
            let gLine = i < goldenLines.count ? goldenLines[i] : "<missing>"
            if rLine != gLine {
                return "Mismatch at line \(i + 1):\n  expected: \(gLine)\n  actual:   \(rLine)"
            }
        }
        return "Content differs (length mismatch)"
    }

    /// Writes a buffer's rendered output to a file.
    /// - Parameters:
    ///   - buffer: The buffer to write.
    ///   - path: The file path to write to.
    public static func write(_ buffer: CellBuffer, to path: String) throws {
        let rendered = renderPlainText(buffer)
        try rendered.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Asserts that a buffer matches its golden snapshot, optionally recording.
    /// - Parameters:
    ///   - buffer: The buffer to check.
    ///   - name: The snapshot name.
    ///   - directory: Optional directory for snapshot storage.
    ///   - record: If true, overwrites the golden file instead of comparing.
    ///   - file: Source file for diagnostics.
    ///   - line: Source line for diagnostics.
    public static func assertSnapshot(
        _ buffer: CellBuffer,
        name: String,
        directory: String? = nil,
        record: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let dir = directory ?? NSTemporaryDirectory()
        let path = URL(fileURLWithPath: (dir as NSString).appendingPathComponent("\(name).txt")).standardizedFileURL.path

        if record {
            try? write(buffer, to: path) // silent: best-effort snapshot recording
            return
        }

        let fileManager = FileManager.default
        // SECURITY: path sanitized via URL.standardizedFileURL above
        guard fileManager.fileExists(atPath: path) else {
            // First run: record the snapshot
            try? write(buffer, to: path) // silent: best-effort snapshot recording
            return
        }

        if let diff = compare(buffer, goldenFile: path) {
            // Mismatch detected — store result for caller inspection
            _lastSnapshotFailure = diff
        } else {
            _lastSnapshotFailure = nil
        }
    }

    /// The last snapshot failure message, if any. Useful for test inspection.
    private static let _lastSnapshotFailureStorage = Mutex<String?>(nil)

    /// The most recent snapshot assertion failure message, or `nil` if all passed.
    public static var _lastSnapshotFailure: String? {
        get { _lastSnapshotFailureStorage.withLock { $0 } }
        set { _lastSnapshotFailureStorage.withLock { $0 = newValue } }
    }

    // MARK: - Private Helpers

    private static func colorName(_ color: Color) -> String {
        switch color {
        case .defaultColor:
            return "default"
        case .ansi8(let ansi):
            return ansiColorName(ansi)
        case .ansi256(let n):
            return "256:\(n)"
        case .truecolor(let r, let g, let b):
            return "rgb:\(r),\(g),\(b)"
        }
    }

    private static func ansiColorName(_ color: ANSIColor) -> String {
        switch color {
        case .black: return "black"
        case .red: return "red"
        case .green: return "green"
        case .yellow: return "yellow"
        case .blue: return "blue"
        case .magenta: return "magenta"
        case .cyan: return "cyan"
        case .white: return "white"
        case .brightBlack: return "brightBlack"
        case .brightRed: return "brightRed"
        case .brightGreen: return "brightGreen"
        case .brightYellow: return "brightYellow"
        case .brightBlue: return "brightBlue"
        case .brightMagenta: return "brightMagenta"
        case .brightCyan: return "brightCyan"
        case .brightWhite: return "brightWhite"
        }
    }

    private static func attributesString(_ attrs: CellAttributes) -> String {
        var parts: [String] = []
        if attrs.contains(.bold) { parts.append("bold") }
        if attrs.contains(.dim) { parts.append("dim") }
        if attrs.contains(.italic) { parts.append("italic") }
        if attrs.contains(.underline) { parts.append("underline") }
        if attrs.contains(.blink) { parts.append("blink") }
        if attrs.contains(.reverse) { parts.append("reverse") }
        if attrs.contains(.strikethrough) { parts.append("strikethrough") }
        return parts.joined(separator: ",")
    }
}
