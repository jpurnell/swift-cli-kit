// SwiftSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for Swift source code.
struct SwiftSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let keywords: Set<String> = [
        "let", "var", "func", "class", "struct", "enum", "protocol", "extension",
        "if", "else", "guard", "switch", "case", "for", "while", "repeat",
        "return", "throw", "throws", "try", "catch", "do", "import", "public",
        "private", "internal", "fileprivate", "open", "static", "final",
        "override", "mutating", "nonmutating", "init", "deinit", "self",
        "super", "nil", "true", "false", "in", "is", "as", "where",
        "typealias", "associatedtype", "some", "any", "async", "await",
        "actor", "nonisolated", "isolated", "sending", "consuming", "borrowing",
    ]

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        // Handle continued block comment
        if state.inBlockComment {
            guard let endRange = remaining.range(of: "*/") else {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }
            let commentEnd = remaining[remaining.startIndex...endRange.upperBound]
            spans.append(StyledSpan(text: String(commentEnd), tokenType: .comment))
            remaining = remaining[endRange.upperBound...]
            state.inBlockComment = false
        }

        while !remaining.isEmpty {
            // Block comment start
            if remaining.hasPrefix("/*") {
                guard let endRange = remaining.range(of: "*/") else {
                    spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                    state.inBlockComment = true
                    return spans
                }
                let commentText = remaining[remaining.startIndex...endRange.upperBound]
                spans.append(StyledSpan(text: String(commentText), tokenType: .comment))
                remaining = remaining[endRange.upperBound...]
                continue
            }

            // Line comment
            if remaining.hasPrefix("//") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // String literal
            if remaining.hasPrefix("\"") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Number
            if let first = remaining.first, first.isNumber {
                let num = consumeNumber(&remaining)
                spans.append(StyledSpan(text: num, tokenType: .number))
                continue
            }

            // Decorator (@attribute)
            if remaining.hasPrefix("@") {
                let dec = consumeDecorator(&remaining)
                spans.append(StyledSpan(text: dec, tokenType: .decorator))
                continue
            }

            // Identifier or keyword
            if let first = remaining.first, first.isLetter || first == "_" {
                let word = consumeWord(&remaining)
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
