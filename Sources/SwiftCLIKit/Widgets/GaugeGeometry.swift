// GaugeGeometry.swift
// SwiftCLIKit
//
// The single source of a gauge's drawing logic — fill counts, track counts, and
// label placement — factored out of `Gauge.render` so that alternative
// renderers (e.g. SwiftGUIKit's token-driven CellRenderer) draw through the exact
// same routine and cannot drift from the terminal output.

import Foundation

/// Geometry and drawing for a horizontal gauge bar. Style-agnostic: callers
/// supply the characters and styles; this type owns *where* cells and the label
/// go, so every renderer produces identical output for identical geometry.
public struct GaugeGeometry: Sendable, Equatable {
    /// The bar width in columns.
    public let width: Int
    /// The column range drawn with the filled character.
    public let filledRange: Range<Int>
    /// The column range drawn with the track (unfilled) character.
    public let unfilledRange: Range<Int>
    /// The starting column for a centered label, or `nil` when there is no label.
    public let labelStartX: Int?

    /// Computes gauge geometry.
    /// - Parameters:
    ///   - width: The bar width in columns (values `<= 0` yield empty ranges).
    ///   - ratio: The fill ratio; clamped to `0...1`.
    ///   - labelLength: The label's character count, or `nil` for no label.
    public init(width: Int, ratio: Double, labelLength: Int?) {
        self.width = width
        let w = Swift.max(width, 0)
        let clamped = Swift.min(Swift.max(ratio, 0.0), 1.0)
        let filled = w > 0 ? Int(Double(w) * clamped) : 0
        self.filledRange = 0..<filled
        self.unfilledRange = filled..<w
        if w > 0, let len = labelLength {
            self.labelStartX = Swift.max((w - len) / 2, 0)
        } else {
            self.labelStartX = nil
        }
    }

    /// Draws the gauge into a frame using the given characters, styles, and label.
    ///
    /// - Parameters:
    ///   - frame: The frame to draw into (row 0).
    ///   - filledChar: The character for the filled portion.
    ///   - filledStyle: The style for the filled portion.
    ///   - unfilledChar: The character for the track portion.
    ///   - unfilledStyle: The style for the track portion.
    ///   - label: An optional centered label overlaid on the bar.
    public func draw(
        into frame: inout Frame,
        filledChar: Character,
        filledStyle: CellStyle,
        unfilledChar: Character,
        unfilledStyle: CellStyle,
        label: String?
    ) {
        for col in filledRange {
            frame.setCell(x: col, y: 0, cell: Cell(
                character: filledChar,
                fg: filledStyle.fg,
                bg: filledStyle.bg,
                attributes: filledStyle.attributes
            ))
        }
        for col in unfilledRange {
            frame.setCell(x: col, y: 0, cell: Cell(
                character: unfilledChar,
                fg: unfilledStyle.fg,
                bg: unfilledStyle.bg,
                attributes: unfilledStyle.attributes
            ))
        }
        if let label, let startX = labelStartX {
            frame.writeText(label, x: startX, y: 0)
        }
    }
}
