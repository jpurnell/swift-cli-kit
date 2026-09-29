// TOMLSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for TOML source.
struct TOMLSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let booleanLiterals: Set<String> = [
        "true", "false",
    ]

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        // Leading whitespace
        if let first = remaining.first, first.isWhitespace {
            let ws = consumeWhitespace(&remaining)
            spans.append(StyledSpan(text: ws, tokenType: .plain))
        }

        guard !remaining.isEmpty else { return spans }

        // Line comment
        if remaining.hasPrefix("#") {
            spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
            return spans
        }

        // Section header ([section] or [[array]])
        if remaining.hasPrefix("[[") {
            var header = ""
            while !remaining.isEmpty {
                let ch = remaining.removeFirst()
                header.append(ch)
                if header.hasSuffix("]]") { break }
            }
            spans.append(StyledSpan(text: header, tokenType: .keyword))
            if !remaining.isEmpty {
                spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
            }
            return spans
        }

        if remaining.hasPrefix("[") {
            var header = ""
            while !remaining.isEmpty {
                let ch = remaining.removeFirst()
                header.append(ch)
                if ch == "]" { break }
            }
            spans.append(StyledSpan(text: header, tokenType: .keyword))
            if !remaining.isEmpty {
                spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
            }
            return spans
        }

        // Key = value pair
        if let eqRange = remaining.range(of: "=") {
            let key = remaining[remaining.startIndex..<eqRange.lowerBound]
            spans.append(StyledSpan(text: String(key), tokenType: .variable))
            spans.append(StyledSpan(text: "=", tokenType: .operator))
            remaining = remaining[eqRange.upperBound...]

            // Consume whitespace after =
            if let first = remaining.first, first.isWhitespace {
                let ws = consumeWhitespace(&remaining)
                spans.append(StyledSpan(text: ws, tokenType: .plain))
            }

            guard !remaining.isEmpty else { return spans }

            // Triple-quoted strings
            if remaining.hasPrefix("\"\"\"") || remaining.hasPrefix("'''") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .string))
                return spans
            }

            // String value
            if remaining.hasPrefix("\"") || remaining.hasPrefix("'") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                if !remaining.isEmpty {
                    spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
                }
                return spans
            }

            // Boolean
            let valueStr = String(remaining).trimmingCharacters(in: .whitespaces)
            if Self.booleanLiterals.contains(valueStr) {
                spans.append(StyledSpan(text: String(remaining), tokenType: .keyword))
                return spans
            }

            // Number or datetime
            if let first = remaining.first, first.isNumber || first == "-" || first == "+" {
                let num = consumeNumber(&remaining)
                if !num.isEmpty {
                    spans.append(StyledSpan(text: num, tokenType: .number))
                    if !remaining.isEmpty {
                        spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
                    }
                    return spans
                }
            }

            // Fallback value
            spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
            return spans
        }

        // Fallback: plain text
        spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
        return spans
    }
}
