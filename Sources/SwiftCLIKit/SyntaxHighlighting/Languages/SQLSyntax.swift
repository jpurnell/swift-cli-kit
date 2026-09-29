// SQLSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for SQL source (ANSI SQL).
struct SQLSyntaxTokenizer: LanguageTokenizer, Sendable {

    /// SQL keywords are case-insensitive; stored lowercase for matching.
    private static let keywords: Set<String> = [
        "select", "from", "where", "insert", "update", "delete", "create",
        "alter", "drop", "join", "left", "right", "inner", "outer", "cross",
        "on", "and", "or", "not", "null", "as", "order", "by", "group",
        "having", "limit", "union", "exists", "in", "between", "like",
        "distinct", "into", "values", "set", "table", "index", "view",
        "begin", "commit", "rollback", "grant", "revoke", "primary", "key",
        "foreign", "references", "constraint", "default", "check", "unique",
        "all", "any", "some", "case", "when", "then", "else", "end",
        "asc", "desc", "is", "true", "false", "count", "sum", "avg",
        "min", "max", "offset", "fetch", "top", "with", "recursive",
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

            // Line comment (--)
            if remaining.hasPrefix("--") {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // String literal (single quote in SQL)
            if remaining.hasPrefix("'") {
                let str = consumeSQLString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Number
            if let first = remaining.first, first.isNumber {
                let num = consumeNumber(&remaining)
                spans.append(StyledSpan(text: num, tokenType: .number))
                continue
            }

            // Identifier or keyword (case-insensitive match)
            if let first = remaining.first, first.isLetter || first == "_" {
                let word = consumeWord(&remaining)
                let isKeyword = Self.keywords.contains(word.lowercased())
                let tokenType: TokenType = isKeyword ? .keyword : .plain
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

// MARK: - SQL-specific helpers

/// Consumes a SQL string literal (single-quoted, with '' escape for embedded quotes).
private func consumeSQLString(_ remaining: inout Substring) -> String {
    var result = String(remaining.removeFirst()) // opening '
    while !remaining.isEmpty {
        let ch = remaining.removeFirst()
        result.append(ch)
        if ch == "'" {
            // Check for escaped quote ('')
            if remaining.first == "'" {
                result.append(remaining.removeFirst())
            } else {
                return result
            }
        }
    }
    return result
}
