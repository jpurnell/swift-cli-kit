// CursorControl.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// ANSI escape sequences for cursor visibility, movement, and shape control.
public enum CursorControl {
    /// Makes the cursor visible (DECTCEM).
    public static let show = "\u{001B}[?25h"
    /// Hides the cursor (DECTCEM).
    public static let hide = "\u{001B}[?25l"

    /// Moves the cursor to an absolute row and column (1-based).
    public static func moveTo(row: Int, column: Int) -> String { "\u{001B}[\(row);\(column)H" }
    /// Moves the cursor up by `n` rows.
    public static func moveUp(_ n: Int) -> String { "\u{001B}[\(n)A" }
    /// Moves the cursor down by `n` rows.
    public static func moveDown(_ n: Int) -> String { "\u{001B}[\(n)B" }
    /// Moves the cursor right by `n` columns.
    public static func moveRight(_ n: Int) -> String { "\u{001B}[\(n)C" }
    /// Moves the cursor left by `n` columns.
    public static func moveLeft(_ n: Int) -> String { "\u{001B}[\(n)D" }
    /// Saves the current cursor position (DECSC via CSI s).
    public static let save = "\u{001B}[s"
    /// Restores a previously saved cursor position (DECRC via CSI u).
    public static let restore = "\u{001B}[u"

    /// Terminal cursor shapes (DECSCUSR).
    public enum Shape: UInt8, Sendable {
        /// Block cursor (DECSCUSR 2).
        case block = 2
        /// Underline cursor (DECSCUSR 4).
        case underline = 4
        /// Bar/beam cursor (DECSCUSR 6).
        case bar = 6
    }

    /// Sets the cursor shape, optionally blinking.
    public static func setShape(_ shape: Shape, blinking: Bool = false) -> String {
        let value = blinking ? shape.rawValue - 1 : shape.rawValue
        return "\u{001B}[\(value) q"
    }
}
