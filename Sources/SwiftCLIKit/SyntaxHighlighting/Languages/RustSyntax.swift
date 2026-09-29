// RustSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for Rust source code.
struct RustSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let keywords: Set<String> = [
        "fn", "let", "mut", "const", "struct", "enum", "impl", "trait",
        "pub", "use", "mod", "match", "if", "else", "loop", "while",
        "for", "return", "async", "await", "unsafe", "where", "Self",
        "self", "super", "crate", "as", "in", "ref", "move", "dyn",
        "type", "static", "extern", "break", "continue", "true", "false",
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

            // Doc comment (///) or line comment (//)
            if remaining.hasPrefix("//") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // Attribute (#[...])
            if remaining.hasPrefix("#[") || remaining.hasPrefix("#![") {
                let attr = consumeRustAttribute(&remaining)
                spans.append(StyledSpan(text: attr, tokenType: .decorator))
                continue
            }

            // Lifetime annotation ('a)
            if remaining.hasPrefix("'") {
                let next = remaining.dropFirst()
                if let first = next.first, first.isLetter {
                    remaining = remaining.dropFirst() // consume '
                    let word = consumeWord(&remaining)
                    spans.append(StyledSpan(text: "'" + word, tokenType: .type))
                    continue
                }
            }

            // Raw string literal (r#"..."#)
            if remaining.hasPrefix("r#") || remaining.hasPrefix("r\"") {
                let str = consumeRustRawString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Byte string literal (b"...")
            if remaining.hasPrefix("b\"") || remaining.hasPrefix("b'") {
                remaining = remaining.dropFirst() // consume b
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: "b" + str, tokenType: .string))
                continue
            }

            // String literal
            if remaining.hasPrefix("\"") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Character literal
            if remaining.hasPrefix("'") {
                // Check if it's a char literal like 'a' or '\n'
                let saved = remaining
                remaining = remaining.dropFirst() // consume '
                if remaining.first == "\\" {
                    remaining = remaining.dropFirst()
                    if !remaining.isEmpty {
                        remaining = remaining.dropFirst()
                    }
                } else if !remaining.isEmpty {
                    remaining = remaining.dropFirst()
                }
                if remaining.first == "'" {
                    remaining = remaining.dropFirst()
                    let consumed = saved[saved.startIndex..<remaining.startIndex]
                    spans.append(StyledSpan(text: String(consumed), tokenType: .string))
                    continue
                }
                // Not a char literal, restore
                remaining = saved
                let ch = String(remaining.removeFirst())
                spans.append(StyledSpan(text: ch, tokenType: .operator))
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

// MARK: - Rust-specific helpers

/// Consumes a Rust attribute like #[derive(Debug)] or #![allow(unused)].
private func consumeRustAttribute(_ remaining: inout Substring) -> String {
    var result = ""
    var depth = 0
    while !remaining.isEmpty {
        let ch = remaining.removeFirst()
        result.append(ch)
        if ch == "[" { depth += 1 }
        if ch == "]" {
            depth -= 1
            if depth <= 0 { return result }
        }
    }
    return result
}

/// Consumes a Rust raw string literal like r#"text"# or r"text".
private func consumeRustRawString(_ remaining: inout Substring) -> String {
    var result = String(remaining.removeFirst()) // 'r'
    var hashCount = 0
    while remaining.first == "#" {
        result.append(remaining.removeFirst())
        hashCount += 1
    }
    guard remaining.first == "\"" else { return result }
    result.append(remaining.removeFirst()) // opening quote

    let closingSequence = "\"" + String(repeating: "#", count: hashCount)
    while !remaining.isEmpty {
        let ch = remaining.removeFirst()
        result.append(ch)
        if result.hasSuffix(closingSequence) {
            return result
        }
    }
    return result
}
