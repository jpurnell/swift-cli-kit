// SyntaxTheme.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// A mapping from ``TokenType`` to colors and attributes for syntax highlighting.
///
/// ```swift
/// let theme = SyntaxTheme.default
/// let keywordColor = theme.color(for: .keyword)
/// ```
public struct SyntaxTheme: Sendable {
    /// Color mappings for each token type.
    public var colors: [TokenType: Color]
    /// Attribute mappings for each token type.
    public var attributes: [TokenType: CellAttributes]

    /// A default dark syntax theme.
    public static let `default` = SyntaxTheme(
        colors: [
            .keyword: .truecolor(r: 198, g: 120, b: 221),
            .type: .truecolor(r: 229, g: 192, b: 123),
            .string: .truecolor(r: 152, g: 195, b: 121),
            .number: .truecolor(r: 209, g: 154, b: 102),
            .comment: .truecolor(r: 92, g: 99, b: 112),
            .decorator: .truecolor(r: 209, g: 154, b: 102),
            .operator: .truecolor(r: 86, g: 182, b: 194),
            .function: .truecolor(r: 97, g: 175, b: 239),
            .variable: .truecolor(r: 224, g: 108, b: 117),
            .plain: .default,
        ],
        attributes: [
            .keyword: .bold,
            .comment: .dim,
        ]
    )

    /// A light syntax theme.
    public static let light = SyntaxTheme(
        colors: [
            .keyword: .truecolor(r: 137, g: 89, b: 168),
            .type: .truecolor(r: 143, g: 118, b: 55),
            .string: .truecolor(r: 80, g: 131, b: 53),
            .number: .truecolor(r: 164, g: 93, b: 29),
            .comment: .truecolor(r: 128, g: 128, b: 128),
            .decorator: .truecolor(r: 164, g: 93, b: 29),
            .operator: .truecolor(r: 51, g: 51, b: 51),
            .function: .truecolor(r: 0, g: 92, b: 158),
            .variable: .truecolor(r: 168, g: 49, b: 49),
            .plain: .default,
        ],
        attributes: [
            .keyword: .bold,
            .comment: .dim,
        ]
    )

    /// Creates a syntax theme with the given mappings.
    /// - Parameters:
    ///   - colors: Token-to-color mappings.
    ///   - attributes: Token-to-attributes mappings.
    public init(
        colors: [TokenType: Color] = [:],
        attributes: [TokenType: CellAttributes] = [:]
    ) {
        self.colors = colors
        self.attributes = attributes
    }

    /// Returns the color for the given token type, or `.default` if unmapped.
    /// - Parameter token: The token type to look up.
    /// - Returns: The mapped color or `.default`.
    public func color(for token: TokenType) -> Color {
        colors[token] ?? .default
    }

    /// Returns the attributes for the given token type, or empty if unmapped.
    /// - Parameter token: The token type to look up.
    /// - Returns: The mapped attributes or empty.
    public func attrs(for token: TokenType) -> CellAttributes {
        attributes[token] ?? []
    }
}
