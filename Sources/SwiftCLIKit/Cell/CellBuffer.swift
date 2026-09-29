// CellBuffer.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A 2D grid of terminal cells representing a screen buffer.
///
/// `CellBuffer` provides indexed access to cells and bulk operations like
/// `fill`, `writeText`, and `clear`.
///
/// ```swift
/// var buf = CellBuffer(width: 80, height: 24)
/// buf[5, 3] = Cell(character: "X", fg: .ansi8(.red))
/// ```
public struct CellBuffer: Sendable, Equatable {
    private var cells: [Cell]
    /// The width of the buffer in columns.
    public let width: Int
    /// The height of the buffer in rows.
    public let height: Int

    /// Creates a buffer filled with empty cells.
    /// - Parameters:
    ///   - width: Number of columns.
    ///   - height: Number of rows.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.cells = Array(repeating: .empty, count: width * height)
    }

    /// Accesses the cell at the given column and row.
    ///
    /// Out-of-bounds reads return ``Cell/empty``; out-of-bounds writes are ignored.
    public subscript(x: Int, y: Int) -> Cell {
        get {
            guard x >= 0, y >= 0, x < width, y < height else { return .empty }
            return cells[y * width + x]
        }
        set {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            cells[y * width + x] = newValue
        }
    }

    /// Fills the given rectangle with a cell value.
    /// - Parameters:
    ///   - rect: The region to fill.
    ///   - cell: The cell to write into every position.
    public mutating func fill(_ rect: Rect, with cell: Cell) {
        let minX = max(rect.x, 0)
        let minY = max(rect.y, 0)
        let maxX = min(rect.x + rect.width, width)
        let maxY = min(rect.y + rect.height, height)
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX {
                cells[y * width + x] = cell
            }
        }
    }

    /// Writes a string horizontally starting at the given position.
    /// - Parameters:
    ///   - text: The string to write.
    ///   - position: The (x, y) starting coordinate.
    ///   - fg: Foreground color for each character.
    ///   - bg: Background color for each character.
    ///   - attributes: Text attributes for each character.
    public mutating func writeText(
        _ text: String,
        at position: (x: Int, y: Int),
        fg: Color = .default,
        bg: Color = .default,
        attributes: CellAttributes = []
    ) {
        guard position.y >= 0, position.y < height else { return }
        var offset = 0
        for ch in text {
            let x = position.x + offset
            guard x >= 0, x < width else {
                // If x < 0, keep advancing; if x >= width, we're done on this row
                if x >= width { break }
                let charWidth = UnicodeWidth.width(of: ch)
                offset += max(charWidth, 1)
                continue
            }
            let charWidth = UnicodeWidth.width(of: ch)
            let cell = Cell(character: ch, fg: fg, bg: bg, attributes: attributes)
            cells[position.y * width + x] = cell
            if charWidth == 2 {
                // Write continuation cell at the next position if in bounds
                let nextX = x + 1
                if nextX < width {
                    let continuation = Cell(character: " ", fg: fg, bg: bg, attributes: attributes)
                    cells[position.y * width + nextX] = continuation
                }
                offset += 2
            } else {
                offset += max(charWidth, 1)
            }
        }
    }

    /// Resets all cells to ``Cell/empty``.
    public mutating func clear() {
        cells = Array(repeating: .empty, count: width * height)
    }
}
