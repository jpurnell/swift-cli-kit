// CellAttributes.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A set of text styling attributes for a terminal cell.
///
/// `CellAttributes` is an `OptionSet` allowing multiple styles to be combined:
/// ```swift
/// let style: CellAttributes = [.bold, .italic, .underline]
/// ```
public struct CellAttributes: OptionSet, Sendable, Equatable, Hashable {
    /// The raw integer value of the option set.
    public let rawValue: UInt8
    /// Creates a cell-attributes option set from a raw value.
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Bold / increased intensity.
    public static let bold          = CellAttributes(rawValue: 1 << 0)
    /// Dim / decreased intensity.
    public static let dim           = CellAttributes(rawValue: 1 << 1)
    /// Italic text.
    public static let italic        = CellAttributes(rawValue: 1 << 2)
    /// Underlined text.
    public static let underline     = CellAttributes(rawValue: 1 << 3)
    /// Blinking text.
    public static let blink         = CellAttributes(rawValue: 1 << 4)
    /// Reverse video (swap foreground/background).
    public static let reverse       = CellAttributes(rawValue: 1 << 5)
    /// Strikethrough text.
    public static let strikethrough = CellAttributes(rawValue: 1 << 6)
}
