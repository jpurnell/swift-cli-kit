// LineEditor.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// The outcome of processing a single key press in a ``LineEditor``.
public enum LineResult: Sendable, Equatable {
    /// The line is still being edited (no terminal action).
    case editing
    /// The user pressed Enter; contains the final line text.
    case completed(String)
    /// End-of-file (Ctrl-D on an empty line).
    case eof
    /// The user pressed Ctrl-C.
    case interrupt
}

/// A stateful, Emacs-style single-line text editor driven by ``Key`` events.
///
/// Supports character insertion, deletion, cursor movement, and Ctrl-key shortcuts
/// (Ctrl-A/E for home/end, Ctrl-K/U for kill, Ctrl-W for word-delete).
///
/// ```swift
/// var editor = LineEditor()
/// _ = editor.handleKey(.character("H"))
/// _ = editor.handleKey(.character("i"))
/// let result = editor.handleKey(.enter)  // .completed("Hi")
/// ```
public struct LineEditor: Sendable {
    /// The current text content of the editor.
    public private(set) var text: String
    /// The cursor offset (in characters from the start).
    public private(set) var cursorPosition: Int

    /// Creates a line editor, optionally pre-filled with text.
    /// - Parameter text: Initial content. The cursor is placed at the end.
    public init(text: String = "") {
        self.text = text
        self.cursorPosition = text.count
    }

    /// Processes a single key press, mutating the editor state accordingly.
    /// - Parameter key: The key event to handle.
    /// - Returns: A ``LineResult`` indicating whether editing continues or a terminal event occurred.
    public mutating func handleKey(_ key: Key) -> LineResult {
        switch key {
        case .character(let ch):
            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            text.insert(ch, at: index)
            cursorPosition += 1
            return .editing

        case .enter:
            return .completed(text)

        case .backspace:
            guard cursorPosition > 0 else { return .editing }
            let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
            text.remove(at: index)
            cursorPosition -= 1
            return .editing

        case .delete:
            guard cursorPosition < text.count else { return .editing }
            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            text.remove(at: index)
            return .editing

        case .arrowLeft:
            cursorPosition = max(0, cursorPosition - 1)
            return .editing

        case .arrowRight:
            cursorPosition = min(text.count, cursorPosition + 1)
            return .editing

        case .home, .ctrlA:
            cursorPosition = 0
            return .editing

        case .end, .ctrlE:
            cursorPosition = text.count
            return .editing

        case .ctrlK:
            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            text = String(text[text.startIndex..<index])
            return .editing

        case .ctrlU:
            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            text = String(text[index...])
            cursorPosition = 0
            return .editing

        case .ctrlW:
            guard cursorPosition > 0 else { return .editing }
            var pos = cursorPosition
            // Skip trailing spaces
            while pos > 0 && text[text.index(text.startIndex, offsetBy: pos - 1)] == " " {
                pos -= 1
            }
            // Delete back to space or start
            while pos > 0 && text[text.index(text.startIndex, offsetBy: pos - 1)] != " " {
                pos -= 1
            }
            let startIdx = text.index(text.startIndex, offsetBy: pos)
            let endIdx = text.index(text.startIndex, offsetBy: cursorPosition)
            text.removeSubrange(startIdx..<endIdx)
            cursorPosition = pos
            return .editing

        case .ctrlD:
            if text.isEmpty {
                return .eof
            }
            guard cursorPosition < text.count else { return .editing }
            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            text.remove(at: index)
            return .editing

        case .ctrlC:
            return .interrupt

        case .ctrlL:
            return .editing

        default:
            return .editing
        }
    }

    /// The text as it should be displayed (currently identical to ``text``).
    public var displayText: String { text }
}
