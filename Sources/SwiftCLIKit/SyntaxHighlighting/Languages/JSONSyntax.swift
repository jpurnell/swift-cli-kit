// JSONSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for JSON data.
struct JSONSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let booleanAndNull: Set<String> = ["true", "false", "null"]

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        while !remaining.isEmpty {
            // Whitespace
            if let first = remaining.first, first.isWhitespace {
                let ws = consumeWhitespace(&remaining)
                spans.append(StyledSpan(text: ws, tokenType: .plain))
                continue
            }

            // String (could be key or value -- detect key by checking for colon after)
            if remaining.hasPrefix("\"") {
                let str = consumeString(&remaining)
                // Check if followed by colon (after optional whitespace) to classify as key
                let afterStr = remaining.drop(while: { $0.isWhitespace })
                let tokenType: TokenType = afterStr.hasPrefix(":") ? .variable : .string
                spans.append(StyledSpan(text: str, tokenType: tokenType))
                continue
            }

            // Number (including negative)
            if let first = remaining.first, first.isNumber || (first == "-" && remaining.count > 1) {
                if first == "-" {
                    let next = remaining.index(after: remaining.startIndex)
                    guard next < remaining.endIndex, remaining[next].isNumber else {
                        let ch = String(remaining.removeFirst())
                        spans.append(StyledSpan(text: ch, tokenType: .operator))
                        continue
                    }
                }
                let num = consumeNumber(&remaining)
                spans.append(StyledSpan(text: num, tokenType: .number))
                continue
            }

            // Boolean / null keywords
            if let first = remaining.first, first.isLetter {
                let word = consumeWord(&remaining)
                let tokenType: TokenType = Self.booleanAndNull.contains(word) ? .keyword : .plain
                spans.append(StyledSpan(text: word, tokenType: tokenType))
                continue
            }

            // Structural characters
            let ch = String(remaining.removeFirst())
            spans.append(StyledSpan(text: ch, tokenType: .operator))
        }
        return spans
    }
}
