// PythonSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for Python source code.
struct PythonSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let keywords: Set<String> = [
        "def", "class", "if", "elif", "else", "for", "while", "return",
        "import", "from", "as", "with", "try", "except", "finally",
        "raise", "pass", "break", "continue", "and", "or", "not", "in",
        "is", "lambda", "yield", "global", "nonlocal", "assert", "del",
        "True", "False", "None", "async", "await",
    ]

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        // Handle continued triple-quoted string
        if state.inMultiLineString {
            guard let endRange = remaining.range(of: "\"\"\"") else {
                spans.append(StyledSpan(text: String(remaining), tokenType: .string))
                return spans
            }
            let strEnd = remaining[remaining.startIndex...endRange.upperBound]
            spans.append(StyledSpan(text: String(strEnd), tokenType: .string))
            remaining = remaining[endRange.upperBound...]
            state.inMultiLineString = false
        }

        while !remaining.isEmpty {
            // Line comment
            if remaining.hasPrefix("#") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // Triple-quoted string
            if remaining.hasPrefix("\"\"\"") {
                remaining = remaining.dropFirst(3)
                guard let endRange = remaining.range(of: "\"\"\"") else {
                    spans.append(StyledSpan(text: "\"\"\"" + String(remaining), tokenType: .string))
                    state.inMultiLineString = true
                    return spans
                }
                let content = remaining[remaining.startIndex..<endRange.upperBound]
                spans.append(StyledSpan(text: "\"\"\"" + String(content), tokenType: .string))
                remaining = remaining[endRange.upperBound...]
                continue
            }

            // String literal (single or double quote)
            if remaining.hasPrefix("\"") || remaining.hasPrefix("'") {
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

            // Decorator
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
