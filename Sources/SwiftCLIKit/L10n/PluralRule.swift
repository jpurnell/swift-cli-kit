// PluralRule.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// CLDR plural categories for cardinal numbers.
///
/// The six standard categories defined by the Unicode CLDR specification.
/// Not all languages use all categories.
public enum PluralCategory: String, Sendable, Codable, CaseIterable {
    case zero
    case one
    case two
    case few
    case many
    case other
}

/// CLDR-based plural rule engine for cardinal numbers.
///
/// Implements a simplified subset of Unicode CLDR plural rules covering
/// the most common language patterns. Languages not explicitly listed
/// fall back to the English rule (one/other).
///
/// ```swift
/// PluralRule.category(for: 1, locale: "en")  // .one
/// PluralRule.category(for: 5, locale: "en")  // .other
/// PluralRule.category(for: 0, locale: "ar")  // .zero
/// ```
///
/// Reference: https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
public enum PluralRule: Sendable {
    /// Returns the CLDR plural category for the given count and locale.
    ///
    /// - Parameters:
    ///   - count: The cardinal number to categorize.
    ///   - locale: A BCP 47 locale identifier (e.g. "en", "ja", "ar").
    ///             Only the language subtag is used.
    /// - Returns: The appropriate ``PluralCategory`` for this count and locale.
    public static func category(for count: Int, locale: String) -> PluralCategory {
        let lang = languageSubtag(from: locale)
        let family = ruleFamily(for: lang)
        return apply(family: family, count: count)
    }

    // MARK: - Private

    /// Identifies the plural rule family for dispatch without closures.
    private enum RuleFamily: Sendable {
        case english
        case noPlurals
        case french
        case arabic
        case polish
        case russian
    }

    private static func languageSubtag(from locale: String) -> String {
        let parts = locale.split(separator: "-")
        guard let first = parts.first else { return locale.lowercased() }
        return String(first).lowercased()
    }

    private static func ruleFamily(for lang: String) -> RuleFamily {
        switch lang {
        // English-like: 1=one, else=other
        case "en", "de", "es", "it", "nl", "sv", "da", "no", "nb", "nn",
             "fi", "el", "he", "hu", "tr", "ca", "et", "bg":
            return .english
        // No plurals: always other
        case "ja", "zh", "ko", "vi", "th", "id", "ms":
            return .noPlurals
        // French-like: 0 or 1 = one
        case "fr", "pt", "hi":
            return .french
        // Arabic
        case "ar":
            return .arabic
        // Polish
        case "pl":
            return .polish
        // Russian-like
        case "ru", "uk", "hr", "sr", "bs":
            return .russian
        default:
            return .english
        }
    }

    private static func apply(family: RuleFamily, count: Int) -> PluralCategory {
        switch family {
        case .english:
            return count == 1 ? .one : .other

        case .noPlurals:
            return .other

        case .french:
            return (count == 0 || count == 1) ? .one : .other

        case .arabic:
            if count == 0 { return .zero }
            if count == 1 { return .one }
            if count == 2 { return .two }
            let mod100 = count % 100
            if mod100 >= 3, mod100 <= 10 { return .few }
            if mod100 >= 11, mod100 <= 99 { return .many }
            return .other

        case .polish:
            if count == 1 { return .one }
            let mod10 = count % 10
            let mod100 = count % 100
            if mod10 >= 2, mod10 <= 4, !(mod100 >= 12 && mod100 <= 14) {
                return .few
            }
            return .other

        case .russian:
            let mod10 = count % 10
            let mod100 = count % 100
            if mod10 == 1, mod100 != 11 { return .one }
            if mod10 >= 2, mod10 <= 4, !(mod100 >= 12 && mod100 <= 14) { return .few }
            return .other
        }
    }
}
