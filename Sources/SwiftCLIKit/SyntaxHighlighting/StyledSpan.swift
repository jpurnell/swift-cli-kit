// StyledSpan.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// A contiguous run of text with uniform syntax highlighting.
///
/// ``SyntaxHighlighter`` returns arrays of `StyledSpan` for each line,
/// where each span has a token type and associated visual styling.
///
/// ```swift
/// let span = StyledSpan(text: "let", tokenType: .keyword, fg: .ansi8(.blue))
/// ```
public struct StyledSpan: Sendable, Equatable {
    /// The text content of this span.
    public let text: String
    /// The semantic token type.
    public let tokenType: TokenType
    /// The foreground color.
    public let fg: Color
    /// The background color.
    public let bg: Color
    /// Text attributes (bold, italic, etc.).
    public let attributes: CellAttributes

    /// Creates a styled span.
    /// - Parameters:
    ///   - text: The text content.
    ///   - tokenType: The semantic token type.
    ///   - fg: Foreground color (default: terminal default).
    ///   - bg: Background color (default: terminal default).
    ///   - attributes: Text attributes (default: none).
    public init(
        text: String,
        tokenType: TokenType,
        fg: Color = .default,
        bg: Color = .default,
        attributes: CellAttributes = []
    ) {
        self.text = text
        self.tokenType = tokenType
        self.fg = fg
        self.bg = bg
        self.attributes = attributes
    }
}
