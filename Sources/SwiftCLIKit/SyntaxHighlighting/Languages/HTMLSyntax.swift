// HTMLSyntax.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Tokenizer for HTML source.
struct HTMLSyntaxTokenizer: LanguageTokenizer, Sendable {

    func tokenize(_ line: String, state: inout TokenizerState) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var remaining = line[...]

        // Handle continued block comment (<!-- ... -->)
        if state.inBlockComment {
            guard let endRange = remaining.range(of: "-->") else {
                spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                return spans
            }
            let commentEnd = remaining[remaining.startIndex...endRange.upperBound]
            spans.append(StyledSpan(text: String(commentEnd), tokenType: .comment))
            remaining = remaining[endRange.upperBound...]
            state.inBlockComment = false
        }

        while !remaining.isEmpty {
            // HTML comment
            if remaining.hasPrefix("<!--") {
                guard let endRange = remaining.range(of: "-->") else {
                    spans.append(StyledSpan(text: String(remaining), tokenType: .comment))
                    state.inBlockComment = true
                    return spans
                }
                let commentText = remaining[remaining.startIndex...endRange.upperBound]
                spans.append(StyledSpan(text: String(commentText), tokenType: .comment))
                remaining = remaining[endRange.upperBound...]
                continue
            }

            // Doctype
            if remaining.hasPrefix("<!") {
                var tag = ""
                while !remaining.isEmpty {
                    let ch = remaining.removeFirst()
                    tag.append(ch)
                    if ch == ">" { break }
                }
                spans.append(StyledSpan(text: tag, tokenType: .keyword))
                continue
            }

            // Closing tag
            if remaining.hasPrefix("</") {
                remaining = remaining.dropFirst(2)
                var tagName = ""
                while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "-" {
                    tagName.append(remaining.removeFirst())
                }
                var closing = ""
                if remaining.first == ">" {
                    closing = String(remaining.removeFirst())
                }
                spans.append(StyledSpan(text: "</" + tagName + closing, tokenType: .keyword))
                continue
            }

            // Opening tag
            if remaining.hasPrefix("<") {
                remaining = remaining.dropFirst()
                var tagName = ""
                while let ch = remaining.first, ch.isLetter || ch.isNumber || ch == "-" {
                    tagName.append(remaining.removeFirst())
                }
                spans.append(StyledSpan(text: "<" + tagName, tokenType: .keyword))

                // Parse attributes
                while !remaining.isEmpty {
                    // Whitespace
                    if let first = remaining.first, first.isWhitespace {
                        let ws = consumeWhitespace(&remaining)
                        spans.append(StyledSpan(text: ws, tokenType: .plain))
                        continue
                    }

                    // Self-closing or end of tag
                    if remaining.hasPrefix("/>") {
                        remaining = remaining.dropFirst(2)
                        spans.append(StyledSpan(text: "/>", tokenType: .keyword))
                        break
                    }
                    if remaining.hasPrefix(">") {
                        remaining = remaining.dropFirst()
                        spans.append(StyledSpan(text: ">", tokenType: .keyword))
                        break
                    }

                    // Attribute name
                    if let first = remaining.first, first.isLetter || first == "_" || first == "-" {
                        var attrName = ""
                        while let ch = remaining.first,
                              ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
                            attrName.append(remaining.removeFirst())
                        }
                        spans.append(StyledSpan(text: attrName, tokenType: .variable))

                        // =
                        if remaining.first == "=" {
                            spans.append(StyledSpan(text: String(remaining.removeFirst()), tokenType: .operator))
                        }

                        // Attribute value
                        if remaining.hasPrefix("\"") || remaining.hasPrefix("'") {
                            let str = consumeString(&remaining)
                            spans.append(StyledSpan(text: str, tokenType: .string))
                        }
                        continue
                    }

                    // Unexpected character in tag -- consume and move on
                    let ch = String(remaining.removeFirst())
                    spans.append(StyledSpan(text: ch, tokenType: .operator))
                    break
                }
                continue
            }

            // Entity (&amp; etc.)
            if remaining.hasPrefix("&") {
                var entity = ""
                while !remaining.isEmpty {
                    let ch = remaining.removeFirst()
                    entity.append(ch)
                    if ch == ";" { break }
                    if ch.isWhitespace || entity.count > 10 { break }
                }
                spans.append(StyledSpan(text: entity, tokenType: .variable))
                continue
            }

            // Plain text content
            var text = ""
            while let ch = remaining.first, ch != "<" && ch != "&" {
                text.append(remaining.removeFirst())
            }
            if !text.isEmpty {
                spans.append(StyledSpan(text: text, tokenType: .plain))
            }
        }
        return spans
    }
}
