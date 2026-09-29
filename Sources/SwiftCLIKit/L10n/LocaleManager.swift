// LocaleManager.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Manages localized string resolution for a SwiftCLIKit application.
///
/// Store a `LocaleManager` in your app's Model. When the user switches
/// locale, update the manager via ``setLocale(_:)`` and the MVU loop
/// re-renders all views automatically.
///
/// ```swift
/// struct MyModel: Sendable {
///     var locale: LocaleManager
///     var counter: Int = 0
/// }
///
/// // In a view, the localized string is what you draw:
/// let model = MyModel(locale: LocaleManager())
/// let greeting = model.locale.localized("greeting")
/// ```
public struct LocaleManager: Sendable {
    /// The currently active locale identifier (e.g. "en", "ja", "es").
    public var currentLocale: String

    /// All loaded strings, keyed by localization key, then by locale identifier.
    /// Structure: [key: [locale: value]]
    public var strings: [String: [String: String]]

    /// All loaded plural strings, keyed by localization key, then by locale,
    /// then by plural category.
    /// Structure: [key: [locale: [category: value]]]
    public var pluralStrings: [String: [String: [PluralCategory: String]]]

    /// Creates a new locale manager.
    /// - Parameters:
    ///   - locale: The initial active locale. Defaults to "en".
    ///   - strings: Pre-loaded simple string tables. Defaults to empty.
    ///   - pluralStrings: Pre-loaded plural string tables. Defaults to empty.
    public init(
        locale: String = "en",
        strings: [String: [String: String]] = [:],
        pluralStrings: [String: [String: [PluralCategory: String]]] = [:]
    ) {
        self.currentLocale = locale
        self.strings = strings
        self.pluralStrings = pluralStrings
    }

    /// Switches the active locale.
    ///
    /// If the locale has no loaded strings, resolution will fall back
    /// to "en" and then to the raw key itself.
    /// - Parameter locale: The locale identifier to switch to.
    public mutating func setLocale(_ locale: String) {
        self.currentLocale = locale
    }

    /// Resolves a localized string for the current locale.
    ///
    /// Falls back to "en" if the key is missing in the current locale,
    /// then to the raw key string itself.
    /// - Parameter key: The localization key to resolve.
    /// - Returns: The localized string, or the key itself as a last resort.
    public func localized(_ key: String) -> String {
        if let localeMap = strings[key] {
            if let value = localeMap[currentLocale] {
                return value
            }
            if let fallback = localeMap["en"] {
                return fallback
            }
        }
        return key
    }

    /// Resolves a pluralized string for the current locale using CLDR rules.
    ///
    /// Selects the correct plural form based on the count, then replaces
    /// any `{count}` placeholder with the count value.
    /// - Parameters:
    ///   - key: The localization key to resolve.
    ///   - count: The count used for plural category selection and replacement.
    /// - Returns: The resolved and interpolated plural string, or the key as fallback.
    public func localized(_ key: String, count: Int) -> String {
        let category = PluralRule.category(for: count, locale: currentLocale)

        if let localeMap = pluralStrings[key] {
            // Try current locale
            if let categoryMap = localeMap[currentLocale],
               let template = categoryMap[category] ?? categoryMap[.other] {
                return template.replacingOccurrences(of: "{count}", with: "\(count)")
            }
            // Fallback to "en"
            if let enMap = localeMap["en"],
               let template = enMap[category] ?? enMap[.other] {
                return template.replacingOccurrences(of: "{count}", with: "\(count)")
            }
        }
        return key
    }

    /// Loads a locale manager from a JSON file.
    ///
    /// The JSON format supports both simple strings and plural forms:
    /// ```json
    /// {
    ///   "greeting": { "en": "Hello", "ja": "こんにちは" },
    ///   "items_count": {
    ///     "en": { "one": "{count} item", "other": "{count} items" },
    ///     "ja": { "other": "{count}個" }
    ///   }
    /// }
    /// ```
    ///
    /// - Parameter jsonPath: Path to the JSON string file.
    /// - Returns: A configured locale manager with all strings loaded.
    /// - Throws: An error if the file cannot be read or parsed.
    public static func load(from jsonPath: String) throws -> LocaleManager {
        let url = URL(fileURLWithPath: jsonPath)
        let data = try Data(contentsOf: url)

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LocaleManagerError.invalidFormat
        }

        var simpleStrings: [String: [String: String]] = [:]
        var plurals: [String: [String: [PluralCategory: String]]] = [:]

        for (key, value) in root {
            guard let localeMap = value as? [String: Any] else { continue }

            var isPlural = false
            for (_, localeValue) in localeMap {
                if localeValue is [String: String] {
                    isPlural = true
                    break
                }
            }

            if isPlural {
                var pluralMap: [String: [PluralCategory: String]] = [:]
                for (locale, localeValue) in localeMap {
                    if let categoryDict = localeValue as? [String: String] {
                        var categories: [PluralCategory: String] = [:]
                        for (catKey, catValue) in categoryDict {
                            if let cat = PluralCategory(rawValue: catKey) {
                                categories[cat] = catValue
                            }
                        }
                        pluralMap[locale] = categories
                    }
                }
                plurals[key] = pluralMap
            } else {
                var stringMap: [String: String] = [:]
                for (locale, localeValue) in localeMap {
                    if let str = localeValue as? String {
                        stringMap[locale] = str
                    }
                }
                simpleStrings[key] = stringMap
            }
        }

        return LocaleManager(
            locale: "en",
            strings: simpleStrings,
            pluralStrings: plurals
        )
    }
}

/// Errors that can occur during locale manager operations.
public enum LocaleManagerError: Error, Sendable {
    /// The JSON file format is not valid.
    case invalidFormat
}
