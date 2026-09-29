// GenericSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Fallback tokenizer for unrecognized languages.
struct GenericSyntaxTokenizer: LanguageTokenizer, Sendable {

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

            // Line comment (// or #)
            if remaining.hasPrefix("//") || remaining.hasPrefix("#") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // String literal (double or single quoted)
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

            // Identifier
            if let first = remaining.first, first.isLetter || first == "_" {
                let word = consumeWord(&remaining)
                spans.append(StyledSpan(text: word, tokenType: .plain))
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
