// QualityGateDashboard.swift
// QualityGateDashboard
//
// A real, useful application of SwiftGUIKit: it turns quality-gate results into a
// single semantic scene (`Node`) that renders to BOTH the terminal (via
// CellRenderer + DiffRenderer → printable ANSI) and a native SwiftUI window (via
// SwiftUIRenderer). One `scene(checks:)`, many surfaces.

import SwiftCLIKit
import SwiftGUIKit

/// The outcome of a single quality-gate check.
public enum GateStatus: Sendable, Equatable, CaseIterable {
    /// Passed with no errors or warnings.
    case passed
    /// Passed with warnings.
    case warning
    /// Failed with errors.
    case failed
}

/// One quality-gate check's result.
public struct GateCheck: Sendable, Equatable {
    /// The check name (e.g. "build", "safety", "doc-coverage").
    public let name: String
    /// The check status.
    public let status: GateStatus
    /// The number of errors reported.
    public let errors: Int
    /// The number of warnings reported.
    public let warnings: Int

    /// Creates a gate-check result.
    public init(name: String, status: GateStatus, errors: Int = 0, warnings: Int = 0) {
        self.name = name
        self.status = status
        self.errors = errors
        self.warnings = warnings
    }
}

/// Builds and renders a quality-gate dashboard.
public enum QualityGateDashboard {

    /// Builds the surface-agnostic dashboard scene for a set of check results.
    /// - Parameter checks: The quality-gate check results.
    /// - Returns: A ``SwiftGUIKit/Node`` renderable on any surface.
    public static func scene(checks: [GateCheck]) -> Node {
        let total = checks.count
        let passed = checks.filter { $0.status == .passed }.count
        let passRate = total > 0 ? Double(passed) / Double(total) : 1
        let totalErrors = checks.reduce(0) { $0 + $1.errors }
        let totalWarnings = checks.reduce(0) { $0 + $1.warnings }

        let summaryColor: ColorRole = checks.contains { $0.status == .failed } ? .destructive
            : (checks.contains { $0.status == .warning } ? .warning : .success)
        let summary = "\(totalErrors) error(s), \(totalWarnings) warning(s)"

        return Block(title: "Quality Gate", borders: .all).node(child:
            .vstack(spacing: .s, [
                StackChild(Paragraph(text: summary, wrap: false).node(color: summaryColor), size: .fit),
                StackChild(.vstack(spacing: .xs, checks.map(row(_:))), size: .flex(1)),
                StackChild(Gauge(ratio: passRate, label: "\(passed)/\(total) passed").node(), size: .fixed(1)),
            ]))
    }

    /// One check row: a status glyph + name on the left, an `E/W` count on the
    /// right, colored by status. Uses text (not an interactive control) so it
    /// renders identically on the terminal and natively — including headless.
    private static func row(_ check: GateCheck) -> StackChild {
        let color: ColorRole = check.status == .passed ? .success
            : (check.status == .failed ? .destructive : .warning)
        let symbols = DefaultSymbolSet()
        let glyph: String
        switch check.status {
        case .passed:  glyph = symbols.mapping(for: .check).unicode     // ✓
        case .warning: glyph = symbols.mapping(for: .warning).unicode   // ⚠
        case .failed:  glyph = symbols.mapping(for: .close).unicode     // ✕
        }
        let detail = "\(check.errors)E \(check.warnings)W"
        let node = Node.hstack(spacing: .s, [
            StackChild(Paragraph(text: "\(glyph) \(check.name)", wrap: false).node(color: color), size: .flex(1)),
            StackChild(Paragraph(text: detail, wrap: false).node(color: color), size: .fixed(detail.count)),
        ])
        return StackChild(node, size: .fixed(1))
    }

    /// Renders the dashboard to a printable ANSI string for the terminal.
    /// - Parameters:
    ///   - checks: The check results.
    ///   - width: The terminal width in columns.
    ///   - height: The terminal height in rows.
    ///   - resolver: The terminal token resolver (default: `TerminalTokenResolver()`).
    ///   - context: The design context (default: `.terminalTruecolor`).
    /// - Returns: An ANSI escape string ready to print to stdout.
    public static func renderTerminal(
        checks: [GateCheck],
        width: Int,
        height: Int,
        resolver: TerminalTokenResolver = TerminalTokenResolver(),
        context: DesignContext = .terminalTruecolor
    ) -> String {
        renderTerminal(node: scene(checks: checks), width: width, height: height, resolver: resolver, context: context)
    }

    /// Renders any scene ``Node`` to a printable ANSI string.
    public static func renderTerminal(
        node: Node,
        width: Int,
        height: Int,
        resolver: TerminalTokenResolver = TerminalTokenResolver(),
        context: DesignContext = .terminalTruecolor
    ) -> String {
        var frame = Frame(buffer: CellBuffer(width: width, height: height),
                          rect: Rect(x: 0, y: 0, width: width, height: height))
        CellRenderer(resolver: resolver, context: context).render(node, into: &frame)
        var diff = DiffRenderer()
        return diff.render(current: frame.cellBuffer, previous: nil)
    }

    /// Renders any scene ``Node`` to a plain-text character grid.
    public static func renderPlainText(
        node: Node,
        width: Int,
        height: Int,
        resolver: TerminalTokenResolver = TerminalTokenResolver(),
        context: DesignContext = .terminalMono
    ) -> String {
        var frame = Frame(buffer: CellBuffer(width: width, height: height),
                          rect: Rect(x: 0, y: 0, width: width, height: height))
        CellRenderer(resolver: resolver, context: context).render(node, into: &frame)
        let buffer = frame.cellBuffer
        return (0..<height).map { y in
            String((0..<width).map { buffer[$0, y].character })
        }.joined(separator: "\n")
    }

    /// Renders the dashboard to a plain-text (no ANSI) grid — useful for CI logs
    /// and non-color terminals.
    /// - Parameters:
    ///   - checks: The check results.
    ///   - width: The width in columns.
    ///   - height: The height in rows.
    ///   - resolver: The terminal token resolver (default: `TerminalTokenResolver()`).
    ///   - context: The design context (default: `.terminalMono`).
    /// - Returns: A newline-separated character grid.
    public static func renderPlainText(
        checks: [GateCheck],
        width: Int,
        height: Int,
        resolver: TerminalTokenResolver = TerminalTokenResolver(),
        context: DesignContext = .terminalMono
    ) -> String {
        var frame = Frame(buffer: CellBuffer(width: width, height: height),
                          rect: Rect(x: 0, y: 0, width: width, height: height))
        CellRenderer(resolver: resolver, context: context).render(scene(checks: checks), into: &frame)
        let buffer = frame.cellBuffer
        var lines: [String] = []
        for y in 0..<height {
            var line = ""
            for x in 0..<width { line.append(buffer[x, y].character) }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}
