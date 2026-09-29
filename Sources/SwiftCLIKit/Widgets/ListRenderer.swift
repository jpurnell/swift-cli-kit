// ListRenderer.swift
// SwiftCLIKit
//
// The one drawing implementation for a selectable list, parameterized by a
// per-item style lookup and an explicit highlight style — factored out of
// `List.render` so alternative renderers (SwiftGUIKit's CellRenderer) draw
// through the exact same routine and cannot drift.

import Foundation

/// Draws a vertical, scrollable, single-highlight list. Item styling is supplied
/// per index; the highlighted (selected) row uses `highlightStyle` and is filled
/// to the frame width.
public enum ListRenderer {

    /// Draws the list into a frame.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - items: The item texts.
    ///   - state: The selection and scroll state.
    ///   - normalStyle: The style for item `i` when not highlighted.
    ///   - highlightStyle: The style for the selected row (filled to width).
    public static func draw(
        into frame: inout Frame,
        items: [String],
        state: ListState,
        normalStyle: (Int) -> CellStyle,
        highlightStyle: CellStyle
    ) {
        guard frame.rect.width > 0, frame.rect.height > 0 else { return }
        guard !items.isEmpty else { return }

        let visibleCount = frame.rect.height
        for rowIdx in 0..<visibleCount {
            let itemIdx = state.scrollOffset + rowIdx
            guard itemIdx < items.count else { break }
            let text = items[itemIdx]
            let isSelected = (state.selectedIndex == itemIdx)
            let style = isSelected ? highlightStyle : normalStyle(itemIdx)

            frame.writeText(text, x: 0, y: rowIdx, fg: style.fg, bg: style.bg, attributes: style.attributes)

            // Fill the rest of the row so the highlight spans the full width.
            // Bounds-guard: text may be wider than the frame (empty fill then).
            if isSelected {
                let fillStart = Swift.min(text.count, frame.rect.width)
                for fillX in fillStart..<frame.rect.width {
                    frame.setCell(x: fillX, y: rowIdx, cell: Cell(
                        character: " ", fg: style.fg, bg: style.bg, attributes: style.attributes
                    ))
                }
            }
        }
    }
}
