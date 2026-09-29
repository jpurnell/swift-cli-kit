// Cell.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A single terminal cell containing a character, colors, and text attributes.
///
/// `Cell` is the fundamental unit of the cell-based rendering pipeline. Each cell
/// occupies one column in the terminal grid.
///
/// ```swift
/// let cell = Cell(character: "A", fg: .ansi8(.red), bg: .default, attributes: [.bold])
/// ```
public struct Cell: Sendable, Equatable, Hashable {
    /// The character displayed in this cell.
    public var character: Character
    /// The foreground color.
    public var fg: Color
    /// The background color.
    public var bg: Color
    /// Text styling attributes (bold, italic, etc.).
    public var attributes: CellAttributes

    /// Creates a new cell with the given properties.
    /// - Parameters:
    ///   - character: The character to display (default: space).
    ///   - fg: Foreground color (default: terminal default).
    ///   - bg: Background color (default: terminal default).
    ///   - attributes: Text attributes (default: none).
    public init(
        character: Character = " ",
        fg: Color = .default,
        bg: Color = .default,
        attributes: CellAttributes = []
    ) {
        self.character = character
        self.fg = fg
        self.bg = bg
        self.attributes = attributes
    }

    /// An empty cell (space, default colors, no attributes).
    public static let empty = Cell()

    /// The display width of this cell's character in terminal columns.
    ///
    /// - Note: Currently returns 1 for all characters. A future implementation
    ///   will handle wide characters (CJK, emoji) correctly.
    public var displayWidth: Int { UnicodeWidth.width(of: character) }
}
