// InputFieldChrome.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-24.

import Foundation

/// The label and three-row box shared by the single-line input widgets,
/// ``TextField`` and ``SecureField``.
enum InputFieldChrome {
    /// Draws the label, then a box to its right filling the rest of the frame's width.
    /// - Parameters:
    ///   - label: Text drawn at the left of row 0; empty for none.
    ///   - style: The style for the label and the border.
    ///   - frame: The frame to draw into.
    /// - Returns: A one-row sub-frame between the borders, clipped so content cannot
    ///   overwrite them, or `nil` when the frame is too narrow for a box with at
    ///   least one content column.
    static func draw(label: String, style: CellStyle, into frame: inout Frame) -> Frame? {
        if !label.isEmpty {
            frame.writeText(label, x: 0, y: 0, fg: style.fg, bg: style.bg, attributes: style.attributes)
        }

        let labelOffset = label.isEmpty ? 0 : UnicodeWidth.displayWidth(label) + 1
        let fieldWidth = max(frame.rect.width - labelOffset, 0)
        guard fieldWidth > 2 else { return nil }

        let box = BoxDrawing.unicode
        let horizontal = String(repeating: box.horizontal, count: fieldWidth - 2)
        let right = labelOffset + fieldWidth - 1
        write(box.topLeft + horizontal + box.topRight, x: labelOffset, y: 0, style: style, into: &frame)
        write(box.vertical, x: labelOffset, y: 1, style: style, into: &frame)
        write(box.vertical, x: right, y: 1, style: style, into: &frame)
        write(box.bottomLeft + horizontal + box.bottomRight, x: labelOffset, y: 2, style: style, into: &frame)

        let rect = frame.rect
        return frame.subFrame(Rect(x: rect.x + labelOffset + 1, y: rect.y + 1, width: fieldWidth - 2, height: 1))
    }

    private static func write(_ text: String, x: Int, y: Int, style: CellStyle, into frame: inout Frame) {
        frame.writeText(text, x: x, y: y, fg: style.fg, bg: style.bg, attributes: style.attributes)
    }
}
