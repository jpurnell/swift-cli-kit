// CSSSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for CSS source.
struct CSSSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let atRules: Set<String> = [ // LIVE: library API for consumers
        "@media", "@keyframes", "@import", "@font-face", "@charset",
        "@supports", "@namespace", "@page", "@layer",
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
            // Block comment
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

            // At-rule (@media, @keyframes, etc.)
            if remaining.hasPrefix("@") {
                var atRule = "@"
                remaining = remaining.dropFirst()
                while let ch = remaining.first, ch.isLetter || ch == "-" {
                    atRule.append(remaining.removeFirst())
                }
                spans.append(StyledSpan(text: atRule, tokenType: .keyword))
                continue
            }

            // Color literal (#fff, #aabbcc)
            if remaining.hasPrefix("#") {
                var color = "#"
                remaining = remaining.dropFirst()
                while let ch = remaining.first, ch.isHexDigit {
                    color.append(remaining.removeFirst())
                }
                if color.count > 1 {
                    spans.append(StyledSpan(text: color, tokenType: .number))
                } else {
                    // # followed by non-hex = ID selector
                    while let ch = remaining.first,
                          ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
                        color.append(remaining.removeFirst())
                    }
                    spans.append(StyledSpan(text: color, tokenType: .type))
                }
                continue
            }

            // Class selector (.class)
            if remaining.hasPrefix(".") {
                let next = remaining.dropFirst()
                if let first = next.first, first.isLetter || first == "_" || first == "-" {
                    var selector = "."
                    remaining = remaining.dropFirst()
                    while let ch = remaining.first,
                          ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
                        selector.append(remaining.removeFirst())
                    }
                    spans.append(StyledSpan(text: selector, tokenType: .type))
                    continue
                }
            }

            // Pseudo-class (::before, :hover)
            if remaining.hasPrefix(":") {
                var pseudo = ""
                while remaining.first == ":" {
                    pseudo.append(String(remaining.removeFirst()))
                }
                while let ch = remaining.first, ch.isLetter || ch == "-" {
                    pseudo.append(remaining.removeFirst())
                }
                spans.append(StyledSpan(text: pseudo, tokenType: .decorator))
                continue
            }

            // String literal
            if remaining.hasPrefix("\"") || remaining.hasPrefix("'") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Number with optional unit
            if let first = remaining.first, first.isNumber {
                let num = consumeNumber(&remaining)
                // Consume unit suffix (px, em, %, rem, vh, vw, etc.)
                var unit = ""
                while let ch = remaining.first, ch.isLetter || ch == "%" {
                    unit.append(remaining.removeFirst())
                }
                spans.append(StyledSpan(text: num + unit, tokenType: .number))
                continue
            }

            // Identifier (property names, element selectors, values)
            if let first = remaining.first, first.isLetter || first == "_" || first == "-" {
                var word = ""
                while let ch = remaining.first,
                      ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
                    word.append(remaining.removeFirst())
                }
                spans.append(StyledSpan(text: word, tokenType: .plain))
                continue
            }

            // Whitespace
            if let first = remaining.first, first.isWhitespace {
                let ws = consumeWhitespace(&remaining)
                spans.append(StyledSpan(text: ws, tokenType: .plain))
                continue
            }

            // Operator / punctuation ({ } ; , etc.)
            let ch = String(remaining.removeFirst())
            spans.append(StyledSpan(text: ch, tokenType: .operator))
        }
        return spans
    }
}
