// RubySyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for Ruby source code.
struct RubySyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let keywords: Set<String> = [
        "def", "end", "class", "module", "if", "elsif", "else", "unless",
        "while", "until", "do", "begin", "rescue", "ensure", "raise",
        "return", "yield", "require", "include", "attr_accessor",
        "attr_reader", "attr_writer", "self", "super", "nil", "true",
        "false", "and", "or", "not", "then", "when", "case",
        "lambda", "proc", "block_given", "defined",
    ]

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        while !remaining.isEmpty {
            // Line comment
            if remaining.hasPrefix("#") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // String literal (double or single quote)
            if remaining.hasPrefix("\"") || remaining.hasPrefix("'") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Symbol (:name)
            if remaining.hasPrefix(":") {
                let next = remaining.dropFirst()
                if let first = next.first, first.isLetter || first == "_" {
                    remaining = remaining.dropFirst() // consume :
                    let word = consumeWord(&remaining)
                    spans.append(StyledSpan(text: ":" + word, tokenType: .variable))
                    continue
                }
            }

            // Instance variable (@var) or class variable (@@var)
            if remaining.hasPrefix("@@") || remaining.hasPrefix("@") {
                let dec = consumeDecorator(&remaining)
                spans.append(StyledSpan(text: dec, tokenType: .variable))
                continue
            }

            // Number
            if let first = remaining.first, first.isNumber {
                let num = consumeNumber(&remaining)
                spans.append(StyledSpan(text: num, tokenType: .number))
                continue
            }

            // Identifier or keyword
            if let first = remaining.first, first.isLetter || first == "_" {
                let word = consumeRubyWord(&remaining)
                let tokenType: TokenType = Self.keywords.contains(word) ? .keyword : .plain
                spans.append(StyledSpan(text: word, tokenType: tokenType))
                continue
            }

            // Whitespace
            if let first = remaining.first, first.isWhitespace {
                let ws = consumeWhitespace(&remaining)
                spans.append(StyledSpan(text: ws, tokenType: .plain))
                continue
            }

            // Operator / punctuation
            let ch = String(remaining.removeFirst())
            spans.append(StyledSpan(text: ch, tokenType: .operator))
        }
        return spans
    }
}

// MARK: - Ruby-specific helpers

/// Consumes a Ruby identifier that may end with ? or !.
private func consumeRubyWord(_ remaining: inout Substring) -> String {
    var result = ""
    while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "_" {
        result.append(remaining.removeFirst())
    }
    // Ruby methods can end with ? or !
    if let ch = remaining.first, ch == "?" || ch == "!" {
        result.append(remaining.removeFirst())
    }
    return result
}
