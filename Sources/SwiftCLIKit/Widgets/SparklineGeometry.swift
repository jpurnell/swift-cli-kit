// SparklineGeometry.swift
// SwiftCLIKit
//
// The per-column block heights of a sparkline — factored out of
// `Sparkline.render` so alternative renderers reproduce the exact same output.

import Foundation

/// Per-column geometry for a sparkline: how many full block cells each column
/// gets, and the partial-block index above them.
public struct SparklineGeometry: Sendable, Equatable {

    /// One column's block breakdown.
    public struct Column: Sendable, Equatable {
        /// The count of full `█` cells drawn from the bottom up.
        public let fullBlocks: Int
        /// The eighths index (`1...7`) of the partial block above, or `0` for none.
        public let partialIndex: Int
    }

    /// The columns, left to right (empty when there is nothing to draw).
    public let columns: [Column]
    /// The frame height these columns were computed for.
    public let height: Int

    /// Block characters indexed by eighths (`0` = space … `8` = full).
    private static let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    /// Computes sparkline geometry.
    /// - Parameters:
    ///   - data: The data points.
    ///   - max: An optional scaling maximum; when `nil`, the data maximum is used.
    ///   - width: The frame width (columns beyond it are dropped).
    ///   - height: The frame height in rows.
    public init(data: [Double], max: Double?, width: Int, height: Int) {
        self.height = height
        guard !data.isEmpty, width > 0, height > 0 else {
            self.columns = []
            return
        }
        let maxVal = max ?? data.max() ?? 1.0
        guard maxVal > 0 else {
            self.columns = []
            return
        }
        let columnCount = Swift.min(data.count, width)
        var cols: [Column] = []
        cols.reserveCapacity(columnCount)
        for col in 0..<columnCount {
            let value = Swift.max(data[col], 0.0)
            let ratio = Swift.min(value / maxVal, 1.0)
            let scaledHeight = ratio * Double(height)
            let fullBlocks = Int(scaledHeight)
            let remainder = scaledHeight - Double(fullBlocks)
            let partialIndex = Int(remainder * 8.0)
            cols.append(Column(fullBlocks: fullBlocks, partialIndex: partialIndex))
        }
        self.columns = cols
    }

    /// Draws the sparkline into a frame with the given style.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - style: The style applied to every cell (the widget is monochrome).
    public func draw(into frame: inout Frame, style: CellStyle) {
        for (col, column) in columns.enumerated() {
            for row in 0..<column.fullBlocks {
                let y = height - 1 - row
                guard y >= 0 else { break }
                frame.setCell(x: col, y: y, cell: Cell(
                    character: "█",
                    fg: style.fg,
                    bg: style.bg,
                    attributes: style.attributes
                ))
            }
            if column.partialIndex > 0 {
                let y = height - 1 - column.fullBlocks
                guard y >= 0 else { continue }
                frame.setCell(x: col, y: y, cell: Cell(
                    character: Self.blocks[column.partialIndex],
                    fg: style.fg,
                    bg: style.bg,
                    attributes: style.attributes
                ))
            }
        }
    }
}
