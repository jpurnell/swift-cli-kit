// DiffRenderer.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Produces an ANSI escape-sequence string representing the delta between two cell buffers.
///
/// `DiffRenderer` compares a current buffer against an optional previous buffer and emits
/// only the escape sequences needed to update changed cells, minimizing terminal I/O.
///
/// A typical render cycle looks like this:
/// ```swift
/// var renderer = DiffRenderer()
/// var previousBuffer: CellBuffer? = nil
///
/// // -- each frame --
/// var buffer = CellBuffer(width: 80, height: 24)
/// let area = Rect(x: 0, y: 0, width: 80, height: 24)
/// var frame = Frame(buffer: buffer, rect: area)
/// // ... render widgets into frame ...
/// let current = frame.cellBuffer
/// let ansi = renderer.render(current: current, previous: previousBuffer)
/// print(ansi, terminator: "")   // write to terminal
/// previousBuffer = current       // save for next diff
/// ```
public struct DiffRenderer: Sendable {
    /// Creates a new diff renderer.
    public init() { }

    /// Renders the difference between two buffers as an ANSI escape-sequence string.
    /// - Parameters:
    ///   - current: The desired screen state.
    ///   - previous: The last rendered state, or `nil` for a full redraw.
    /// - Returns: A string of ANSI escape sequences to update the terminal.
    public mutating func render(current: CellBuffer, previous: CellBuffer?) -> String {
        var output = ""
        var lastWriteX = -2
        var lastWriteY = -1
        var activeFG: Color?
        var activeBG: Color?
        var activeAttrs: CellAttributes?

        for y in 0..<current.height {
            for x in 0..<current.width {
                let cell = current[x, y]
                let shouldDraw: Bool

                if let prev = previous {
                    shouldDraw = (cell != prev[x, y])
                } else {
                    // Full redraw: skip empty cells
                    shouldDraw = (cell != .empty)
                }

                guard shouldDraw else { continue }

                // Cursor positioning — skip if cursor is already at the right spot
                let isAdjacent = (y == lastWriteY && x == lastWriteX + 1)
                if !isAdjacent {
                    output += CursorControl.moveTo(row: y + 1, column: x + 1)
                }

                // Style — emit SGR only when style changes
                if cell.fg != activeFG || cell.bg != activeBG || cell.attributes != activeAttrs {
                    output += styleEscape(for: cell)
                    activeFG = cell.fg
                    activeBG = cell.bg
                    activeAttrs = cell.attributes
                }

                output.append(cell.character)
                lastWriteX = x
                lastWriteY = y
            }
        }

        // Only emit wrapper sequences if we actually wrote something
        guard !output.isEmpty else { return "" }

        // Reset terminal attributes after rendering to prevent color bleed
        // into unwritten areas (empty cells that were skipped)
        output += "\u{001B}[0m"

        return output
    }

    // MARK: - Private

    /// Builds a single combined SGR sequence for a cell's style.
    private func styleEscape(for cell: Cell) -> String {
        var params: [String] = ["0"] // reset

        // Foreground
        switch cell.fg {
        case .defaultColor:
            params.append("39")  // SGR 39 = default foreground
        case .ansi8(let c):
            if c.rawValue < 8 {
                params.append("\(30 + c.rawValue)")
            } else {
                params.append("\(90 + c.rawValue - 8)")
            }
        case .ansi256(let idx):
            params.append("38;5;\(idx)")
        case .truecolor(let r, let g, let b):
            params.append("38;2;\(r);\(g);\(b)")
        }

        // Background
        switch cell.bg {
        case .defaultColor:
            params.append("49")  // SGR 49 = default background
        case .ansi8(let c):
            if c.rawValue < 8 {
                params.append("\(40 + c.rawValue)")
            } else {
                params.append("\(100 + c.rawValue - 8)")
            }
        case .ansi256(let idx):
            params.append("48;5;\(idx)")
        case .truecolor(let r, let g, let b):
            params.append("48;2;\(r);\(g);\(b)")
        }

        // Attributes
        if cell.attributes.contains(.bold) { params.append("1") }
        if cell.attributes.contains(.dim) { params.append("2") }
        if cell.attributes.contains(.italic) { params.append("3") }
        if cell.attributes.contains(.underline) { params.append("4") }
        if cell.attributes.contains(.blink) { params.append("5") }
        if cell.attributes.contains(.reverse) { params.append("7") }
        if cell.attributes.contains(.strikethrough) { params.append("9") }

        return "\u{1B}[\(params.joined(separator: ";"))m"
    }
}
