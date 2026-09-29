// PolyglotTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Polyglot — v1.7.0 Language Tokenizers")
struct PolyglotTests {

    @Test("JavaScript: 'const' detected as .keyword")
    func javaScriptKeyword() {
        let hl = SyntaxHighlighter(language: .javascript)
        let spans = hl.highlight("const x = async () => {}")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "const" }))
        #expect(keywords.contains(where: { $0.text == "async" }))
    }

    @Test("TypeScript: 'interface' detected as .keyword")
    func typeScriptKeyword() {
        let hl = SyntaxHighlighter(language: .typescript)
        let spans = hl.highlight("interface Foo extends Bar {}")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "interface" }))
        #expect(keywords.contains(where: { $0.text == "extends" }))
    }

    @Test("Go: 'func' and 'go' detected as .keyword")
    func goKeyword() {
        let hl = SyntaxHighlighter(language: .go)
        let spans = hl.highlight("go func() { return nil }")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "go" }))
        #expect(keywords.contains(where: { $0.text == "func" }))
        #expect(keywords.contains(where: { $0.text == "return" }))
        #expect(keywords.contains(where: { $0.text == "nil" }))
    }

    @Test("Rust: 'fn' and 'let mut' detected as .keyword")
    func rustKeyword() {
        let hl = SyntaxHighlighter(language: .rust)
        let spans = hl.highlight("fn main() { let mut x = 5; }")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "fn" }))
        #expect(keywords.contains(where: { $0.text == "let" }))
        #expect(keywords.contains(where: { $0.text == "mut" }))
    }

    @Test("Ruby: 'def' and 'end' detected as .keyword")
    func rubyKeyword() {
        let hl = SyntaxHighlighter(language: .ruby)
        let spans = hl.highlight("def greet(name) return end")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "def" }))
        #expect(keywords.contains(where: { $0.text == "return" }))
        #expect(keywords.contains(where: { $0.text == "end" }))
    }

    @Test("Shell: 'if', 'then', 'fi' detected as .keyword")
    func shellKeyword() {
        let hl = SyntaxHighlighter(language: .shell)
        let spans = hl.highlight("if [ -f file ]; then export PATH; fi")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "if" }))
        #expect(keywords.contains(where: { $0.text == "then" }))
        #expect(keywords.contains(where: { $0.text == "export" }))
        #expect(keywords.contains(where: { $0.text == "fi" }))
    }

    @Test("YAML: key detected as .keyword in key-value pair")
    func yamlKey() {
        let hl = SyntaxHighlighter(language: .yaml)
        let spans = hl.highlight("name: SwiftCLIKit")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "name" }))
    }

    @Test("TOML: section header detected as .keyword")
    func tomlSection() {
        let hl = SyntaxHighlighter(language: .toml)
        let spans = hl.highlight("[package]")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "[package]" }))
    }

    @Test("SQL: 'SELECT' and 'FROM' detected as .keyword (case-insensitive)")
    func sqlKeyword() {
        let hl = SyntaxHighlighter(language: .sql)
        let spans = hl.highlight("SELECT name FROM users WHERE id = 1")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "SELECT" }))
        #expect(keywords.contains(where: { $0.text == "FROM" }))
        #expect(keywords.contains(where: { $0.text == "WHERE" }))
    }

    @Test("HTML: tag name detected as .keyword")
    func htmlTag() {
        let hl = SyntaxHighlighter(language: .html)
        let spans = hl.highlight("<div class=\"main\">Hello</div>")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text.contains("div") }))
    }

    @Test("CSS: @media at-rule detected as .keyword")
    func cssAtRule() {
        let hl = SyntaxHighlighter(language: .css)
        let spans = hl.highlight("@media screen { .header { color: red; } }")
        let keywords = spans.filter { $0.tokenType == .keyword }
        #expect(keywords.contains(where: { $0.text == "@media" }))
    }
}
