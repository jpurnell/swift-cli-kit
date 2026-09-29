// ShellSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for Shell (Bash/Zsh) source code.
struct ShellSyntaxTokenizer: LanguageTokenizer, Sendable {

    private static let keywords: Set<String> = [
        "if", "then", "elif", "else", "fi", "for", "do", "done",
        "while", "until", "case", "esac", "function", "return",
        "local", "export", "source", "alias", "unset", "in",
        "select", "declare", "readonly", "typeset", "trap",
        "eval", "exec", "set", "shift", "exit",
    ]

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        while !remaining.isEmpty {
            // Line comment
            if remaining.hasPrefix("#") {
                // Check if it's a shebang or just a comment
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }

            // Variable expansion ($VAR, ${VAR})
            if remaining.hasPrefix("$") {
                let variable = consumeShellVariable(&remaining)
                spans.append(StyledSpan(text: variable, tokenType: .variable))
                continue
            }

            // Double-quoted string (allows variable expansion)
            if remaining.hasPrefix("\"") {
                let str = consumeString(&remaining)
                spans.append(StyledSpan(text: str, tokenType: .string))
                continue
            }

            // Single-quoted string (literal)
            if remaining.hasPrefix("'") {
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

            // Operator / punctuation (pipes, redirections, etc.)
            let ch = String(remaining.removeFirst())
            spans.append(StyledSpan(text: ch, tokenType: .operator))
        }
        return spans
    }
}

// MARK: - Shell-specific helpers

/// Consumes a shell variable expansion like $VAR, ${VAR}, or ${VAR:-default}.
private func consumeShellVariable(_ remaining: inout Substring) -> String {
    var result = String(remaining.removeFirst()) // '$'
    guard !remaining.isEmpty else { return result }

    // ${...} form
    if remaining.first == "{" {
        result.append(remaining.removeFirst())
        var depth = 1
        while !remaining.isEmpty, depth > 0 {
            let ch = remaining.removeFirst()
            result.append(ch)
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1 }
        }
        return result
    }

    // $(...) command substitution
    if remaining.first == "(" {
        result.append(remaining.removeFirst())
        var depth = 1
        while !remaining.isEmpty, depth > 0 {
            let ch = remaining.removeFirst()
            result.append(ch)
            if ch == "(" { depth += 1 }
            if ch == ")" { depth -= 1 }
        }
        return result
    }

    // Simple $VAR
    while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "_" {
        result.append(remaining.removeFirst())
    }
    return result
}
