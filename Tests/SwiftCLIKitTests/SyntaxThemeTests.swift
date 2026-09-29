// SyntaxThemeTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("SyntaxTheme")
struct SyntaxThemeTests {

    @Test("default theme has colors for keyword, string, and comment")
    func defaultTheme() {
        let theme = SyntaxTheme.default
        // A proper default theme should map at least keyword, string, comment
        #expect(theme.colors[.keyword] == .truecolor(r: 198, g: 120, b: 221))
        #expect(theme.colors[.string] == .truecolor(r: 152, g: 195, b: 121))
        #expect(theme.colors[.comment] == .truecolor(r: 92, g: 99, b: 112))
    }

    @Test("color(for:) returns mapped color")
    func colorForToken() {
        let theme = SyntaxTheme(
            colors: [.keyword: .ansi8(.blue), .string: .ansi8(.green)]
        )
        #expect(theme.color(for: .keyword) == .ansi8(.blue))
        #expect(theme.color(for: .string) == .ansi8(.green))
        #expect(theme.color(for: .number) == .default)
    }

    @Test("light theme has different colors from default")
    func lightTheme() {
        let def = SyntaxTheme.default
        let light = SyntaxTheme.light
        // At least one color should differ between themes
        let anyDifference = TokenType.allCases.contains { token in
            def.color(for: token) != light.color(for: token)
        }
        #expect(anyDifference)
    }
}
