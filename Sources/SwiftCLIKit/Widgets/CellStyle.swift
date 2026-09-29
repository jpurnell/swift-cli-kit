// CellStyle.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A composite style combining foreground color, background color, and text attributes.
///
/// `CellStyle` is a convenience type used by widget APIs to specify the visual
/// appearance of text and regions without listing each component separately.
///
/// ```swift
/// let highlight = CellStyle(fg: .ansi8(.yellow), bg: .ansi8(.blue), attributes: [.bold])
/// ```
public struct CellStyle: Sendable, Equatable {
    /// The foreground color.
    public var fg: Color
    /// The background color.
    public var bg: Color
    /// Text styling attributes (bold, italic, etc.).
    public var attributes: CellAttributes

    /// Creates a cell style with the given properties.
    /// - Parameters:
    ///   - fg: Foreground color (default: terminal default).
    ///   - bg: Background color (default: terminal default).
    ///   - attributes: Text attributes (default: none).
    public init(fg: Color = .default, bg: Color = .default, attributes: CellAttributes = []) {
        self.fg = fg
        self.bg = bg
        self.attributes = attributes
    }
}
