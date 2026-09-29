// SyntaxHighlighter.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Highlights source code lines into arrays of ``StyledSpan``.
///
/// ```swift
/// let hl = SyntaxHighlighter(language: .swift)
/// let spans = hl.highlight("let x = 42")
/// // spans[0].tokenType == .keyword  (when correctly implemented)
/// ```
public struct SyntaxHighlighter: Sendable {
    /// The language this highlighter targets.
    public let language: SyntaxLanguage
    /// The color theme for highlighting.
    public let theme: SyntaxTheme

    /// Creates a highlighter for the given language and theme.
    /// - Parameters:
    ///   - language: The source language.
    ///   - theme: The syntax theme (default: `.default`).
    public init(language: SyntaxLanguage, theme: SyntaxTheme = .default) {
        self.language = language
        self.theme = theme
    }

    /// Highlights a single line of source code.
    /// - Parameter line: The source line to highlight.
    /// - Returns: An array of styled spans covering the entire line.
    public func highlight(_ line: String) -> [StyledSpan] {
        var state = TokenizerState()
        let tokenizer = Self.tokenizer(for: language)
        let spans = tokenizer.tokenize(line, state: &state)
        return spans.map { span in
            StyledSpan(
                text: span.text,
                tokenType: span.tokenType,
                fg: theme.color(for: span.tokenType),
                bg: span.bg,
                attributes: theme.attrs(for: span.tokenType)
            )
        }
    }

    /// Highlights multiple lines of source code.
    /// - Parameter lines: The source lines to highlight.
    /// - Returns: An array of span arrays, one per input line.
    public func highlight(lines: [String]) -> [[StyledSpan]] {
        var state = TokenizerState()
        let tokenizer = Self.tokenizer(for: language)
        return lines.map { line in
            let spans = tokenizer.tokenize(line, state: &state)
            return spans.map { span in
                StyledSpan(
                    text: span.text,
                    tokenType: span.tokenType,
                    fg: theme.color(for: span.tokenType),
                    bg: span.bg,
                    attributes: theme.attrs(for: span.tokenType)
                )
            }
        }
    }

    /// Returns the appropriate tokenizer for a given language.
    private static func tokenizer(for language: SyntaxLanguage) -> any LanguageTokenizer {
        switch language {
        case .swift: return SwiftSyntaxTokenizer()
        case .python: return PythonSyntaxTokenizer()
        case .json: return JSONSyntaxTokenizer()
        case .markdown: return MarkdownSyntaxTokenizer()
        case .javascript: return JavaScriptSyntaxTokenizer()
        case .typescript: return TypeScriptSyntaxTokenizer()
        case .go: return GoSyntaxTokenizer()
        case .rust: return RustSyntaxTokenizer()
        case .ruby: return RubySyntaxTokenizer()
        case .shell: return ShellSyntaxTokenizer()
        case .yaml: return YAMLSyntaxTokenizer()
        case .toml: return TOMLSyntaxTokenizer()
        case .sql: return SQLSyntaxTokenizer()
        case .html: return HTMLSyntaxTokenizer()
        case .css: return CSSSyntaxTokenizer()
        case .generic: return GenericSyntaxTokenizer()
        }
    }
}
