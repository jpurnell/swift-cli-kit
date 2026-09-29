// YAMLSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for YAML source.
struct YAMLSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let booleanLiterals: Set<String> = [
        "true", "false", "yes", "no", "on", "off",
    ]

    private static let nullLiterals: Set<String> = [
        "null", "~",
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

        // Document markers (--- or ...)
        if remaining.hasPrefix("---") || remaining.hasPrefix("...") {
            spans.append(StyledSpan(text: String(remaining), tokenType: .keyword))
            return spans
        }

        // Anchor (&name) or alias (*name)
        if remaining.hasPrefix("&") || remaining.hasPrefix("*") {
            let marker = String(remaining.removeFirst())
            let word = consumeWord(&remaining)
            spans.append(StyledSpan(text: marker + word, tokenType: .variable))
            if !remaining.isEmpty {
                spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
            }
            return spans
        }

        // Tag (!!type)
        if remaining.hasPrefix("!!") || remaining.hasPrefix("!") {
            var tag = ""
            while let ch = remaining.first, !ch.isWhitespace {
                tag.append(remaining.removeFirst())
            }
            spans.append(StyledSpan(text: tag, tokenType: .type))
            if !remaining.isEmpty {
                spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
            }
            return spans
        }

        // List item prefix (- )
        if remaining.hasPrefix("- ") {
            remaining = remaining.dropFirst(2)
            spans.append(StyledSpan(text: "- ", tokenType: .operator))
        }

        // Key: value pair -- look for the colon
        if let colonRange = remaining.range(of: ":") {
            let afterColon = remaining[colonRange.upperBound...]
            // Must be followed by whitespace or end-of-line to be a key
            if afterColon.isEmpty || (afterColon.first?.isWhitespace == true) {
                let key = remaining[remaining.startIndex..<colonRange.lowerBound]
                spans.append(StyledSpan(text: String(key), tokenType: .keyword))
                spans.append(StyledSpan(text: ":", tokenType: .operator))
                remaining = afterColon

                // Consume whitespace after colon
                if let first = remaining.first, first.isWhitespace {
                    let ws = consumeWhitespace(&remaining)
                    spans.append(StyledSpan(text: ws, tokenType: .plain))
                }

                guard !remaining.isEmpty else { return spans }

                // Inline comment after value
                if remaining.hasPrefix("#") {
                    spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
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

                // Check for boolean/null literals or number
                let valueStr = String(remaining).trimmingCharacters(in: .whitespaces)
                if Self.booleanLiterals.contains(valueStr.lowercased()) {
                    spans.append(StyledSpan(text: String(remaining), tokenType: .keyword))
                    return spans
                }
                if Self.nullLiterals.contains(valueStr.lowercased()) {
                    spans.append(StyledSpan(text: String(remaining), tokenType: .keyword))
                    return spans
                }
                if let first = remaining.first, first.isNumber || first == "-" {
                    let num = consumeNumber(&remaining)
                    if !num.isEmpty {
                        spans.append(StyledSpan(text: num, tokenType: .number))
                        if !remaining.isEmpty {
                            spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
                        }
                        return spans
                    }
                }

                // Plain value
                spans.append(StyledSpan(text: String(remaining), tokenType: .string))
                return spans
            }
        }

        // Fallback: plain text
        spans.append(StyledSpan(text: String(remaining), tokenType: .plain))
        return spans
    }
}
