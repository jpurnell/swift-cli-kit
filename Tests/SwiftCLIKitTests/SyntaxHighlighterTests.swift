// SyntaxHighlighterTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("SyntaxHighlighter")
struct SyntaxHighlighterTests {

    @Test("Swift keyword 'let' detected as .keyword token")
    func swiftKeyword() throws {
        let hl = SyntaxHighlighter(language: .swift)
        let spans = hl.highlight("let x = 5")
        let keywordSpan = try #require(spans.first(where: { $0.tokenType == .keyword }))
        #expect(keywordSpan.text == "let")
    }

    @Test("Swift line comment detected as .comment token")
    func swiftComment() throws {
        let hl = SyntaxHighlighter(language: .swift)
        let spans = hl.highlight("// comment")
        let commentSpan = try #require(spans.first(where: { $0.tokenType == .comment }))
        #expect(commentSpan.text.contains("comment"))
    }

    @Test("Swift string literal detected as .string token")
    func swiftString() throws {
        let hl = SyntaxHighlighter(language: .swift)
        let spans = hl.highlight("let s = \"hello\"")
        let stringSpan = try #require(spans.first(where: { $0.tokenType == .string }))
        #expect(stringSpan.text.contains("hello"))
    }

    @Test("JSON key and number detected")
    func jsonStructure() {
        let hl = SyntaxHighlighter(language: .json)
        let spans = hl.highlight("{\"key\": 1}")
        // Should have at least a key span and a number span
        let hasKey = spans.contains(where: { $0.tokenType == .string || $0.tokenType == .variable })
        let hasNumber = spans.contains(where: { $0.tokenType == .number })
        #expect(hasKey)
        #expect(hasNumber)
    }

    @Test("Markdown heading detected as keyword")
    func markdownHeading() throws {
        let hl = SyntaxHighlighter(language: .markdown)
        let spans = hl.highlight("# Title")
        let headingSpan = try #require(spans.first(where: { $0.tokenType == .keyword }))
        #expect(headingSpan.text.contains("#"))
    }

    @Test("generic language returns at least strings and numbers")
    func genericFallback() {
        let hl = SyntaxHighlighter(language: .generic)
        let spans = hl.highlight("x = 42 + \"hello\"")
        let hasNumber = spans.contains(where: { $0.tokenType == .number })
        let hasString = spans.contains(where: { $0.tokenType == .string })
        #expect(hasNumber)
        #expect(hasString)
    }

    @Test("language detection from file extension")
    func languageDetection() {
        #expect(SyntaxLanguage.detect(fileExtension: "swift") == .swift)
        #expect(SyntaxLanguage.detect(fileExtension: "py") == .python)
        #expect(SyntaxLanguage.detect(fileExtension: "xyz") == .generic)
        #expect(SyntaxLanguage.detect(filename: "index.js") == .javascript)
    }
}
