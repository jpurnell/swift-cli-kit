// TextArea.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// The outcome of a key press handled by a ``TextArea``.
public enum TextAreaResult: Sendable, Equatable {
    /// The text content changed.
    case changed(String)
    /// The key was not consumed by the text area.
    case unhandled
}

/// A multi-line text input widget with scrolling support.
///
/// ```swift
/// var area = TextArea(text: "Hello\nWorld")
/// let result = area.handleKey(.character("!"))
/// // result == .changed("Hello\nWorld!")
/// ```
public struct TextArea: Sendable {
    /// The lines of text content.
    public var lines: [String]
    /// The current cursor row (zero-based).
    public var cursorRow: Int
    /// The current cursor column (zero-based).
    public var cursorCol: Int
    /// The scroll offset for vertical scrolling.
    public var scrollOffset: Int

    /// Creates a text area with the given initial text.
    /// - Parameter text: Initial content (newlines create multiple lines).
    public init(text: String = "") {
        if text.isEmpty {
            self.lines = [""]
        } else {
            self.lines = text.lines
        }
        self.cursorRow = self.lines.count - 1
        self.cursorCol = self.lines[self.lines.count - 1].count
        self.scrollOffset = 0
    }

    /// The full text content joined with newlines.
    public var text: String {
        lines.joined(separator: "\n")
    }

    /// Processes a key press and returns the result.
    /// - Parameter key: The key event to handle.
    /// - Returns: A ``TextAreaResult`` describing the outcome.
    public mutating func handleKey(_ key: Key) -> TextAreaResult {
        switch key {
        case .character(let ch):
            guard cursorRow >= 0, cursorRow < lines.count else { return .unhandled }
            let line = lines[cursorRow]
            let safeCol = min(cursorCol, line.count)
            let index = line.index(line.startIndex, offsetBy: safeCol)
            var newLine = line
            newLine.insert(ch, at: index)
            lines[cursorRow] = newLine
            cursorCol = safeCol + 1
            return .changed(text)

        case .enter:
            guard cursorRow >= 0, cursorRow < lines.count else { return .unhandled }
            let line = lines[cursorRow]
            let safeCol = min(cursorCol, line.count)
            let splitIndex = line.index(line.startIndex, offsetBy: safeCol)
            let before = String(line[line.startIndex..<splitIndex])
            let after = String(line[splitIndex...])
            lines[cursorRow] = before
            lines.insert(after, at: cursorRow + 1)
            cursorRow += 1
            cursorCol = 0
            return .changed(text)

        case .backspace:
            guard cursorRow >= 0, cursorRow < lines.count else { return .unhandled }
            if cursorCol > 0 {
                let line = lines[cursorRow]
                let safeCol = min(cursorCol, line.count)
                let removeIndex = line.index(line.startIndex, offsetBy: safeCol - 1)
                var newLine = line
                newLine.remove(at: removeIndex)
                lines[cursorRow] = newLine
                cursorCol = safeCol - 1
                return .changed(text)
            } else if cursorRow > 0 {
                // Merge with previous line
                let currentLine = lines[cursorRow]
                let prevLength = lines[cursorRow - 1].count
                lines[cursorRow - 1] += currentLine
                lines.remove(at: cursorRow)
                cursorRow -= 1
                cursorCol = prevLength
                return .changed(text)
            }
            return .unhandled

        case .arrowUp:
            guard cursorRow > 0 else { return .unhandled }
            cursorRow -= 1
            cursorCol = min(cursorCol, lines[cursorRow].count)
            return .unhandled

        case .arrowDown:
            guard cursorRow < lines.count - 1 else { return .unhandled }
            cursorRow += 1
            cursorCol = min(cursorCol, lines[cursorRow].count)
            return .unhandled

        case .arrowLeft:
            if cursorCol > 0 {
                cursorCol -= 1
            }
            return .unhandled

        case .arrowRight:
            guard cursorRow >= 0, cursorRow < lines.count else { return .unhandled }
            if cursorCol < lines[cursorRow].count {
                cursorCol += 1
            }
            return .unhandled

        default:
            return .unhandled
        }
    }

    /// Renders this text area into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - focused: Whether this text area currently has focus.
    public func render(into frame: inout Frame, focused: Bool) {
        let visibleRows = frame.rect.height
        guard visibleRows > 0 else { return }

        let attrs: CellAttributes = focused ? .bold : []
        for row in 0..<visibleRows {
            let lineIndex = scrollOffset + row
            guard lineIndex < lines.count else { break }
            let lineText = String(lines[lineIndex].prefix(frame.rect.width))
            frame.writeText(lineText, x: 0, y: row, attributes: attrs)
        }
    }
}
