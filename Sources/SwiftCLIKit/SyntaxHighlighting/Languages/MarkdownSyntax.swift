// MarkdownSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for Markdown documents.
struct MarkdownSyntaxTokenizer: LanguageTokenizer, Sendable {

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        // Heading: line starts with one or more '#'
        let trimmed = remaining.drop(while: { $0 == " " })
        if trimmed.hasPrefix("#") {
            spans.append(StyledSpan(text: String(remaining), tokenType: .keyword))
            return spans
        }

        while !remaining.isEmpty {
            // Inline code: `code`
            if remaining.hasPrefix("`") {
                let code = consumeDelimited(&remaining, delimiter: "`")
                spans.append(StyledSpan(text: code, tokenType: .string))
                continue
            }

            // Bold: **text**
            if remaining.hasPrefix("**") {
                let bold = consumeDelimited(&remaining, delimiter: "**")
                spans.append(StyledSpan(text: bold, tokenType: .keyword))
                continue
            }

            // Link: [text](url)
            if remaining.hasPrefix("[") {
                let linkResult = consumeLink(&remaining)
                for span in linkResult {
                    spans.append(span)
                }
                continue
            }

            // Plain text: consume until next special character
            var plain = ""
            while let first = remaining.first,
                  first != "`" && first != "*" && first != "[" {
                plain.append(remaining.removeFirst())
            }
            if !plain.isEmpty {
                spans.append(StyledSpan(text: plain, tokenType: .plain))
            }
        }
        return spans
    }

    /// Consumes a delimited span like `code` or **bold**.
    private func consumeDelimited(_ remaining: inout Substring, delimiter: String) -> String {
        var result = ""
        // Consume opening delimiter
        result += delimiter
        remaining = remaining.dropFirst(delimiter.count)

        // Find closing delimiter
        while !remaining.isEmpty {
            if remaining.hasPrefix(delimiter) {
                result += delimiter
                remaining = remaining.dropFirst(delimiter.count)
                return result
            }
            result.append(remaining.removeFirst())
        }
        return result
    }

    /// Consumes a markdown link [text](url) producing separate spans.
    private func consumeLink(_ remaining: inout Substring) -> [StyledSpan] {
        var spans: [StyledSpan] = []

        // Consume '['
        remaining = remaining.dropFirst()
        var text = "["

        // Find ']'
        while !remaining.isEmpty {
            let ch = remaining.removeFirst()
            text.append(ch)
            if ch == "]" { break }
        }

        // Check for '(' immediately after ']'
        guard remaining.hasPrefix("(") else {
            spans.append(StyledSpan(text: text, tokenType: .function))
            return spans
        }

        spans.append(StyledSpan(text: text, tokenType: .function))

        // Consume url part
        remaining = remaining.dropFirst()
        var url = "("
        while !remaining.isEmpty {
            let ch = remaining.removeFirst()
            url.append(ch)
            if ch == ")" { break }
        }
        spans.append(StyledSpan(text: url, tokenType: .string))

        return spans
    }
}
