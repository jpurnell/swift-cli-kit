// MenuRenderer.swift
// SwiftCLIKit
//
// The one drawing implementation for a vertical menu — factored out of
// `Menu.render` so alternative renderers (SwiftGUIKit's CellRenderer) draw
// through the exact same routine and cannot drift. Adds an optional overflow
// indicator (off for the legacy widget, which truncates silently).

import Foundation

/// Draws a vertical menu: left-aligned labels, right-aligned key hints, selected
/// and disabled rows filled. Optionally reserves the last row for an overflow
/// indicator when items exceed the frame height.
public enum MenuRenderer {

    /// Draws the menu into a frame.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - items: The items as `(label, keyHint, enabled)`.
    ///   - selectedIndex: The selected item index.
    ///   - normalStyle: The style for ordinary rows.
    ///   - highlightStyle: The style for the selected row.
    ///   - disabledStyle: The style for disabled rows (and the overflow indicator).
    ///   - showOverflow: When `true` and items exceed height, reserve the last row.
    ///   - overflowText: The text drawn on the overflow row.
    public static func draw(
        into frame: inout Frame,
        items: [(label: String, keyHint: String?, enabled: Bool)],
        selectedIndex: Int,
        normalStyle: CellStyle,
        highlightStyle: CellStyle,
        disabledStyle: CellStyle,
        showOverflow: Bool = false,
        overflowText: String = "…"
    ) {
        let width = frame.rect.width
        guard width > 0, frame.rect.height > 0 else { return }
        guard !items.isEmpty else { return }

        let height = frame.rect.height
        let truncated = showOverflow && items.count > height
        let rowsToDraw = truncated ? Swift.max(0, height - 1) : Swift.min(items.count, height)

        for rowIdx in 0..<rowsToDraw {
            let item = items[rowIdx]
            let isSelected = (rowIdx == selectedIndex)
            let style: CellStyle
            if !item.enabled { style = disabledStyle }
            else if isSelected { style = highlightStyle }
            else { style = normalStyle }

            frame.writeText(item.label, x: 0, y: rowIdx,
                            fg: style.fg, bg: style.bg, attributes: style.attributes)

            if let hint = item.keyHint {
                let hintX = Swift.max(0, width - hint.count)
                frame.writeText(hint, x: hintX, y: rowIdx,
                                fg: style.fg, bg: style.bg, attributes: style.attributes)
            }

            // Fill the gap between label and key hint on styled rows.
            // Bounds-guarded: labels/hints may exceed the frame width.
            if isSelected || !item.enabled {
                let hintStart = item.keyHint.map { width - $0.count } ?? width
                let lo = Swift.max(0, Swift.min(item.label.count, width))
                let hi = Swift.max(lo, Swift.min(hintStart, width))
                for fillX in lo..<hi {
                    frame.setCell(x: fillX, y: rowIdx, cell: Cell(
                        character: " ", fg: style.fg, bg: style.bg, attributes: style.attributes))
                }
            }
        }

        if truncated {
            frame.writeText(overflowText, x: 0, y: height - 1,
                            fg: disabledStyle.fg, bg: disabledStyle.bg, attributes: disabledStyle.attributes)
        }
    }
}
