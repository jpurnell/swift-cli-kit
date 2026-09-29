// JavaScriptSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for JavaScript source code.
struct JavaScriptSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let keywords: Set<String> = [
        "const", "let", "var", "function", "class", "async", "await", "yield",
        "import", "export", "if", "else", "for", "while", "return", "throw",
        "try", "catch", "finally", "new", "typeof", "instanceof", "switch",
        "case", "break", "continue", "default", "do", "in", "of", "delete",
        "void", "this", "super", "extends", "static", "get", "set",
        "true", "false", "null", "undefined", "with", "debugger",
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

            // Template literal (backtick)
            if remaining.hasPrefix("`") {
                let str = consumeTemplateLiteral(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // String literal (double or single quote)
            if remaining.hasPrefix("\"") || remaining.hasPrefix("'") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Arrow function operator
            if remaining.hasPrefix("=>") {
                remaining = remaining.dropFirst(2)
                spans.append(StyledSpan(text: "=>", tokenType: .operator))
                continue
            }

            // Number
            if let first = remaining.first, first.isNumber {
                let num = consumeNumber(&remaining)
                spans.append(StyledSpan(text: num, tokenType: .number))
                continue
            }

            // Identifier or keyword
            if let first = remaining.first, first.isLetter || first == "_" || first == "$" {
                let word = consumeJSWord(&remaining)
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

// MARK: - JavaScript-specific helpers

/// Consumes an identifier that may start with $ or _.
private func consumeJSWord(_ remaining: inout Substring) -> String {
    var result = ""
    while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "_" || ch == "$" {
        result.append(remaining.removeFirst())
    }
    return result
}

/// Consumes a template literal delimited by backticks.
private func consumeTemplateLiteral(_ remaining: inout Substring) -> String {
    var result = String(remaining.removeFirst()) // opening backtick
    while !remaining.isEmpty {
        let ch = remaining.removeFirst()
        result.append(ch)
        if ch == "\\" {
            guard !remaining.isEmpty else { break }
            result.append(remaining.removeFirst())
        } else if ch == "`" {
            return result
        }
    }
    return result
}
