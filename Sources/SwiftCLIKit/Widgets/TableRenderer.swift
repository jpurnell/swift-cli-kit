// TableRenderer.swift
// SwiftCLIKit
//
// The one drawing implementation for a table — factored out of `Table.render` so
// alternative renderers (SwiftGUIKit's CellRenderer) draw through the exact same
// routine and cannot drift. Generic `Table<Row>` projects its rows through the
// per-column render closures into concrete cell strings before drawing.

import Foundation

/// Draws a table: a header row (with an optional sort indicator glyph) and data
/// rows with column layout, selection highlight, and scroll.
public enum TableRenderer {

    /// Draws the table into a frame.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - headers: The column header texts.
    ///   - widths: The per-column width constraints.
    ///   - cells: The projected cell texts, `rows × columns`.
    ///   - selectedRow: The selected data-row index, if any.
    ///   - scrollOffset: The first visible data-row index.
    ///   - sortIndicator: The `(column, ascending)` to mark, if any.
    ///   - sortAscendingGlyph: The glyph appended to an ascending-sorted header.
    ///   - sortDescendingGlyph: The glyph appended to a descending-sorted header.
    ///   - normalStyle: The style for ordinary data rows.
    ///   - highlightStyle: The style for the selected data row (filled to width).
    ///   - headerStyle: The style for the header row.
    public static func draw(
        into frame: inout Frame,
        headers: [String],
        widths: [Layout.Constraint],
        cells: [[String]],
        selectedRow: Int?,
        scrollOffset: Int,
        sortIndicator: (column: Int, ascending: Bool)?,
        sortAscendingGlyph: String,
        sortDescendingGlyph: String,
        normalStyle: CellStyle,
        highlightStyle: CellStyle,
        headerStyle: CellStyle
    ) {
        guard frame.rect.width > 0, frame.rect.height > 0 else { return }

        let columnWidths: [Int] = widths.map { c in
            switch c {
            case .fixed(let w): return w
            case .min(let w): return w
            case .max(let w): return w
            case .ratio(let num, let den):
                guard den > 0 else { return 0 }
                return (num * frame.rect.width) / den
            case .percentage(let pct):
                return (Int(pct) * frame.rect.width) / 100
            }
        }

        // Row 0: header, with an optional sort indicator glyph.
        var colX = 0
        for (i, header) in headers.enumerated() {
            guard i < columnWidths.count else { break }
            var headerText = header
            if let sort = sortIndicator, sort.column == i {
                headerText += sort.ascending ? sortAscendingGlyph : sortDescendingGlyph
            }
            frame.writeText(headerText, x: colX, y: 0,
                            fg: headerStyle.fg, bg: headerStyle.bg, attributes: headerStyle.attributes)
            colX += columnWidths[i]
        }

        // Data rows from y = 1, respecting scrollOffset.
        let visibleRowCount = frame.rect.height - 1
        guard visibleRowCount > 0 else { return }

        for rowIdx in 0..<visibleRowCount {
            let dataIdx = scrollOffset + rowIdx
            guard dataIdx < cells.count else { break }
            let rowCells = cells[dataIdx]
            let isSelected = (selectedRow == dataIdx)
            let style = isSelected ? highlightStyle : normalStyle

            var cx = 0
            for (i, text) in rowCells.enumerated() {
                guard i < columnWidths.count else { break }
                frame.writeText(text, x: cx, y: rowIdx + 1,
                                fg: style.fg, bg: style.bg, attributes: style.attributes)
                cx += columnWidths[i]
            }

            // Fill remaining cells for the selected row. Bounds-guard: accumulated
            // column widths may exceed the frame width.
            if isSelected {
                let fillStart = Swift.min(cx, frame.rect.width)
                for fillX in fillStart..<frame.rect.width {
                    frame.setCell(x: fillX, y: rowIdx + 1, cell: Cell(
                        character: " ", fg: style.fg, bg: style.bg, attributes: style.attributes))
                }
            }
        }
    }
}
