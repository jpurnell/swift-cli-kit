// ThemeLoaderTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ThemeLoader")
struct ThemeLoaderTests {

    private func validThemeJSON() -> String {
        """
        {
            "name": "test-theme",
            "primary": {"type": "truecolor", "r": 100, "g": 149, "b": 237},
            "secondary": {"type": "ansi8", "value": 6},
            "error": {"type": "ansi8", "value": 1},
            "warning": {"type": "ansi8", "value": 3},
            "success": {"type": "ansi8", "value": 2},
            "muted": {"type": "ansi256", "value": 245},
            "surface": {"type": "ansi256", "value": 236},
            "onSurface": {"type": "ansi8", "value": 7},
            "background": {"type": "ansi8", "value": 0},
            "onBackground": {"type": "ansi8", "value": 7},
            "border": {"type": "ansi256", "value": 240},
            "highlight": {"type": "ansi8", "value": 4},
            "highlightText": {"type": "ansi8", "value": 15}
        }
        """
    }

    @Test("load valid JSON parses correctly")
    func loadValidJSON() throws {
        let theme = try ThemeLoader.load(json: validThemeJSON())
        #expect(theme.name == "test-theme")
        #expect(theme.primary == .truecolor(r: 100, g: 149, b: 237))
        #expect(theme.error == .ansi8(.red))
    }

    @Test("load from file path succeeds")
    func loadFromFile() throws {
        let tmpDir = NSTemporaryDirectory()
        let path = tmpDir + "theme_loader_test.json"
        try Data(validThemeJSON().utf8).write(to: URL(fileURLWithPath: path))
        let theme = try ThemeLoader.load(path: path)
        #expect(theme.name == "test-theme")
    }

    @Test("load JSON missing required field throws")
    func loadMissingField() {
        let json = """
        {
            "name": "incomplete",
            "primary": {"type": "ansi8", "value": 1}
        }
        """
        #expect(throws: (any Error).self) {
            try ThemeLoader.load(json: json)
        }
    }

    @Test("load malformed JSON throws")
    func loadMalformedJSON() {
        let json = "{ not valid json }"
        #expect(throws: (any Error).self) {
            try ThemeLoader.load(json: json)
        }
    }
}
