// TextField.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// The outcome of a key press handled by a ``TextField``.
public enum TextFieldResult: Sendable, Equatable {
    /// The text content changed.
    case changed(String)
    /// The user pressed Enter with the current text.
    case submitted(String)
    /// The user pressed Escape.
    case cancelled
    /// The key was not consumed by the text field.
    case unhandled
}

/// A single-line text input widget wrapping ``LineEditor``.
///
/// ```swift
/// var field = TextField(label: "Name", placeholder: "Enter your name")
/// let result = field.handleKey(.character("A"))
/// // result == .changed("A")
/// ```
public struct TextField: Sendable {
    /// The underlying line editor.
    public var editor: LineEditor
    /// Placeholder text shown when the field is empty.
    public var placeholder: String
    /// The label displayed to the left of the input area.
    public var label: String
    /// The style applied when the field is not focused.
    public var style: CellStyle
    /// The style applied when the field is focused.
    public var focusedStyle: CellStyle

    /// Creates a text field widget.
    /// - Parameters:
    ///   - label: The label text.
    ///   - placeholder: Placeholder text shown when empty.
    ///   - text: Initial text content.
    ///   - style: The unfocused style.
    ///   - focusedStyle: The focused style.
    public init(
        label: String = "",
        placeholder: String = "",
        text: String = "",
        style: CellStyle = CellStyle(),
        focusedStyle: CellStyle = CellStyle(attributes: .bold)
    ) {
        self.label = label
        self.placeholder = placeholder
        self.editor = LineEditor(text: text)
        self.style = style
        self.focusedStyle = focusedStyle
    }

    /// The current text value.
    public var text: String { editor.displayText }

    /// Processes a key press and returns the result.
    /// - Parameter key: The key event to handle.
    /// - Returns: A ``TextFieldResult`` describing the outcome.
    public mutating func handleKey(_ key: Key) -> TextFieldResult {
        switch key {
        case .enter:
            return .submitted(editor.text)
        case .escape:
            return .cancelled
        case .tab:
            return .unhandled
        default:
            let before = editor.text
            _ = editor.handleKey(key)
            let after = editor.text
            if after != before {
                return .changed(after)
            }
            return .unhandled
        }
    }

    /// Renders this text field into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - focused: Whether this field currently has focus.
    public func render(into frame: inout Frame, focused: Bool) {
        let activeStyle = focused ? focusedStyle : style

        // Draw label
        if !label.isEmpty {
            frame.writeText(
                label,
                x: 0, y: 0,
                fg: activeStyle.fg, bg: activeStyle.bg,
                attributes: activeStyle.attributes
            )
        }

        let labelOffset = label.isEmpty ? 0 : label.count + 1
        let fieldWidth = max(frame.rect.width - labelOffset, 0)
        guard fieldWidth > 2 else { return }

        // Draw border
        let box = BoxDrawing.unicode
        frame.writeText(box.topLeft, x: labelOffset, y: 0,
                        fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)
        for col in 1..<(fieldWidth - 1) {
            frame.writeText(box.horizontal, x: labelOffset + col, y: 0,
                            fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)
        }
        frame.writeText(box.topRight, x: labelOffset + fieldWidth - 1, y: 0,
                        fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)

        // Content row
        frame.writeText(box.vertical, x: labelOffset, y: 1,
                        fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)
        let contentWidth = fieldWidth - 2
        if editor.text.isEmpty {
            // Show placeholder in dim style
            let displayPlaceholder = String(placeholder.prefix(contentWidth))
            frame.writeText(
                displayPlaceholder,
                x: labelOffset + 1, y: 1,
                fg: activeStyle.fg, bg: activeStyle.bg,
                attributes: .dim
            )
        } else {
            let displayText = String(editor.text.prefix(contentWidth))
            frame.writeText(
                displayText,
                x: labelOffset + 1, y: 1,
                fg: activeStyle.fg, bg: activeStyle.bg,
                attributes: activeStyle.attributes
            )
        }
        frame.writeText(box.vertical, x: labelOffset + fieldWidth - 1, y: 1,
                        fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)

        // Bottom border
        frame.writeText(box.bottomLeft, x: labelOffset, y: 2,
                        fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)
        for col in 1..<(fieldWidth - 1) {
            frame.writeText(box.horizontal, x: labelOffset + col, y: 2,
                            fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)
        }
        frame.writeText(box.bottomRight, x: labelOffset + fieldWidth - 1, y: 2,
                        fg: activeStyle.fg, bg: activeStyle.bg, attributes: activeStyle.attributes)
    }
}
