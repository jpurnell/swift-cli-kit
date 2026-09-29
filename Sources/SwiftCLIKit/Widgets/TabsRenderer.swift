// TabsRenderer.swift
// SwiftCLIKit
//
// The one drawing implementation for a tab bar — factored out of `Tabs.render`
// so alternative renderers (SwiftGUIKit's CellRenderer) draw through the exact
// same routine and cannot drift.

import Foundation

/// Draws a horizontal tab bar: titles separated by `separator`, the active tab
/// in `activeStyle`, and an optional underline beneath the active tab.
public enum TabsRenderer {

    /// Draws the tab bar into a frame.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - titles: The tab titles.
    ///   - activeIndex: The active tab index.
    ///   - separator: The string drawn between tabs (in `inactiveStyle`).
    ///   - underline: An optional underline character beneath the active tab (row 1).
    ///   - activeStyle: The style for the active tab.
    ///   - inactiveStyle: The style for inactive tabs and separators.
    public static func draw(
        into frame: inout Frame,
        titles: [String],
        activeIndex: Int,
        separator: String,
        underline: Character?,
        activeStyle: CellStyle,
        inactiveStyle: CellStyle
    ) {
        guard !titles.isEmpty else { return }

        var col = 0
        for (index, title) in titles.enumerated() {
            if index > 0 {
                frame.writeText(separator, x: col, y: 0,
                                fg: inactiveStyle.fg, bg: inactiveStyle.bg, attributes: inactiveStyle.attributes)
                col += separator.count
            }

            let isActive = index == activeIndex
            let style = isActive ? activeStyle : inactiveStyle
            let startCol = col

            frame.writeText(title, x: col, y: 0, fg: style.fg, bg: style.bg, attributes: style.attributes)
            col += title.count

            if isActive, let underlineChar = underline, frame.rect.height > 1 {
                for ux in startCol..<col {
                    frame.setCell(x: ux, y: 1, cell: Cell(
                        character: underlineChar, fg: style.fg, bg: style.bg, attributes: style.attributes))
                }
            }
        }
    }
}
