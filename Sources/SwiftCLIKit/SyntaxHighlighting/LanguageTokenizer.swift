// LanguageTokenizer.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Internal protocol for language-specific tokenizers.
protocol LanguageTokenizer: Sendable {
    /// Tokenizes a single line of source code.
    /// - Parameters:
    ///   - line: The source line to tokenize.
    ///   - state: Mutable tokenizer state for tracking multi-line constructs.
    /// - Returns: An array of styled spans covering the line.
    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan]
}

/// State carried between lines for multi-line constructs (block comments, strings).
struct TokenizerState: Sendable {
    /// Whether we are inside a block comment.
    var inBlockComment: Bool = false
    /// Whether we are inside a multi-line string literal.
    var inMultiLineString: Bool = false
}

// MARK: - Shared tokenizer helpers

/// Consumes a double-quoted or single-quoted string from the front of `remaining`.
/// Handles backslash escapes. Returns the consumed text including delimiters.
func consumeString(_ remaining: inout Substring) -> String {
    guard let quote = remaining.first else { return "" }
    var result = String(remaining.removeFirst()) // opening quote

    while !remaining.isEmpty {
        let ch = remaining.removeFirst()
        result.append(ch)
        if ch == "\\" {
            // Escaped character -- consume next char too
            guard !remaining.isEmpty else { break }
            result.append(remaining.removeFirst())
        } else if ch == quote {
            return result
        }
    }
    return result
}

/// Consumes a numeric literal (integer or float, including hex prefix 0x).
func consumeNumber(_ remaining: inout Substring) -> String {
    var result = ""
    // Optional leading minus
    if remaining.first == "-" {
        result.append(remaining.removeFirst())
    }
    // Check for hex prefix
    if remaining.hasPrefix("0x") || remaining.hasPrefix("0X") {
        result.append(remaining.removeFirst()) // '0'
        result.append(remaining.removeFirst()) // 'x'
        while let ch = remaining.first, ch.isHexDigit || ch == "_" {
            result.append(remaining.removeFirst())
        }
        return result
    }
    // Decimal digits
    while let ch = remaining.first, ch.isNumber || ch == "_" {
        result.append(remaining.removeFirst())
    }
    // Decimal point
    if remaining.first == "." {
        let afterDot = remaining.dropFirst()
        if let next = afterDot.first, next.isNumber {
            result.append(remaining.removeFirst()) // '.'
            while let ch = remaining.first, ch.isNumber || ch == "_" {
                result.append(remaining.removeFirst())
            }
        }
    }
    // Exponent
    if let ch = remaining.first, ch == "e" || ch == "E" {
        result.append(remaining.removeFirst())
        if let sign = remaining.first, sign == "+" || sign == "-" {
            result.append(remaining.removeFirst())
        }
        while let ch = remaining.first, ch.isNumber {
            result.append(remaining.removeFirst())
        }
    }
    return result
}

/// Consumes an identifier word (letters, digits, underscores).
func consumeWord(_ remaining: inout Substring) -> String {
    var result = ""
    while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "_" {
        result.append(remaining.removeFirst())
    }
    return result
}

/// Consumes a decorator starting with `@` followed by an identifier.
func consumeDecorator(_ remaining: inout Substring) -> String {
    var result = String(remaining.removeFirst()) // '@'
    while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "_" {
        result.append(remaining.removeFirst())
    }
    return result
}

/// Consumes contiguous whitespace.
func consumeWhitespace(_ remaining: inout Substring) -> String {
    var result = ""
    while let ch = remaining.first, ch.isWhitespace {
        result.append(remaining.removeFirst())
    }
    return result
}
