// ThemeTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Theme")
struct ThemeTests {

    @Test("dark theme has correct name and non-default colors")
    func darkThemeExists() {
        let theme = Theme.dark
        #expect(theme.name == "dark")
        // All semantic colors should be non-default (not all .ansi8(.white))
        #expect(theme.primary != .default || theme.error != .default || theme.success != .default)
    }

    @Test("light theme has correct name")
    func lightThemeExists() {
        let theme = Theme.light
        #expect(theme.name == "light")
    }

    @Test("style generation uses correct theme roles")
    func styleGeneration() {
        let theme = Theme.dark
        let style = theme.style(fg: \.error, bg: \.surface, attributes: .bold)
        #expect(style.fg == theme.error)
        #expect(style.bg == theme.surface)
        #expect(style.attributes == .bold)
    }

    @Test("Codable round-trip preserves theme")
    func codableRoundTrip() throws {
        let original = Theme.dark
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Theme.self, from: data)
        #expect(decoded == original)
    }

    @Test("equality: same themes equal, different themes not equal")
    func equalityCheck() {
        #expect(Theme.dark == Theme.dark)
        #expect(Theme.dark != Theme.light)
    }
}
