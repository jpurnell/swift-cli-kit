// LocalizationTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
import Testing
@testable import SwiftCLIKit

@Suite struct LocalizationTests {

    // MARK: - LocaleManager Tests

    /// Localized "en" returns the English string.
    @Test func localizedEnglishReturnsEnglishString() {
        let manager = LocaleManager(
            locale: "en",
            strings: ["greeting": ["en": "Hello", "ja": "こんにちは"]]
        )
        #expect(manager.localized("greeting") == "Hello")
    }

    /// SetLocale "ja" returns the Japanese string.
    @Test func setLocaleJapaneseReturnsJapaneseString() {
        var manager = LocaleManager(
            locale: "en",
            strings: ["greeting": ["en": "Hello", "ja": "こんにちは"]]
        )
        manager.setLocale("ja")
        #expect(manager.localized("greeting") == "こんにちは")
    }

    /// Missing key returns the key itself as fallback.
    @Test func missingKeyReturnsKeyAsFallback() {
        let manager = LocaleManager(locale: "en")
        #expect(manager.localized("nonexistent_key") == "nonexistent_key")
    }

    /// Pluralized count=1 returns "one" form, count=5 returns "other" form.
    @Test func pluralizedEnglish() {
        let manager = LocaleManager(
            locale: "en",
            pluralStrings: [
                "items_count": [
                    "en": [
                        .one: "{count} item",
                        .other: "{count} items",
                    ]
                ]
            ]
        )
        #expect(manager.localized("items_count", count: 1) == "1 item")
        #expect(manager.localized("items_count", count: 5) == "5 items")
        #expect(manager.localized("items_count", count: 0) == "0 items")
    }

    /// Load from JSON file produces a working locale manager.
    @Test func loadFromJSONFile() throws {
        let json = """
        {
            "greeting": { "en": "Hello", "es": "Hola" },
            "items_count": {
                "en": { "one": "{count} item", "other": "{count} items" }
            }
        }
        """

        // Everything this test writes stays under the temp root; `standardized`
        // resolves any traversal so the prefix check below is meaningful.
        let sandboxRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).standardized
        let tempDir = sandboxRoot
            .appendingPathComponent("SwiftCLIKitL10n_\(UUID().uuidString)", isDirectory: true)
            .standardized
        #expect(tempDir.path.hasPrefix(sandboxRoot.path), "temp dir escaped the sandbox root")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("strings.json").standardized
        try json.write(to: url, atomically: true, encoding: .utf8)

        var manager = try LocaleManager.load(from: url.path)
        #expect(manager.localized("greeting") == "Hello")

        manager.setLocale("es")
        #expect(manager.localized("greeting") == "Hola")

        manager.setLocale("en")
        #expect(manager.localized("items_count", count: 1) == "1 item")
        #expect(manager.localized("items_count", count: 3) == "3 items")
    }

    /// TerminalFormatter truncates number output to maxWidth.
    @Test func terminalFormatterTruncatesToMaxWidth() {
        let wide = TerminalFormatter.formatNumber(1_234_567.89, locale: "en", maxWidth: 20)
        #expect(wide.count <= 20)
        #expect(wide.contains("1"))

        let narrow = TerminalFormatter.formatNumber(1_234_567.89, locale: "en", maxWidth: 5)
        #expect(narrow.count <= 5)
    }

    // MARK: - PluralRule Tests

    /// English plural rules: 1=one, everything else=other.
    @Test func pluralRuleEnglish() {
        #expect(PluralRule.category(for: 1, locale: "en") == .one)
        #expect(PluralRule.category(for: 0, locale: "en") == .other)
        #expect(PluralRule.category(for: 5, locale: "en") == .other)
        #expect(PluralRule.category(for: 21, locale: "en") == .other)
    }

    /// Arabic plural rules cover all six categories.
    @Test func pluralRuleArabic() {
        #expect(PluralRule.category(for: 0, locale: "ar") == .zero)
        #expect(PluralRule.category(for: 1, locale: "ar") == .one)
        #expect(PluralRule.category(for: 2, locale: "ar") == .two)
        #expect(PluralRule.category(for: 6, locale: "ar") == .few)
        #expect(PluralRule.category(for: 11, locale: "ar") == .many)
        #expect(PluralRule.category(for: 100, locale: "ar") == .other)
    }

    /// Japanese always returns .other (no plural forms).
    @Test func pluralRuleJapanese() {
        #expect(PluralRule.category(for: 0, locale: "ja") == .other)
        #expect(PluralRule.category(for: 1, locale: "ja") == .other)
        #expect(PluralRule.category(for: 5, locale: "ja") == .other)
    }

    /// TerminalFormatter date respects maxWidth.
    @Test func terminalFormatterDateRespectsMaxWidth() {
        let date = Date(timeIntervalSince1970: 0)  // 1970-01-01
        let narrow = TerminalFormatter.formatDate(date, locale: "en", maxWidth: 4)
        #expect(narrow.count <= 4)
    }

    /// The year-only fallback uses the requested locale's calendar, not the machine's.
    @Test func terminalFormatterYearFallbackUsesLocaleCalendar() {
        let date = Date(timeIntervalSince1970: 15_638_400)  // 1970-07-01, Shōwa 45
        let year = TerminalFormatter.formatDate(date, locale: "ja_JP@calendar=japanese", maxWidth: 2)
        #expect(year == "45")
    }
}
