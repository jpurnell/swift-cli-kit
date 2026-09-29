// ThemeLoader.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Loads ``Theme`` instances from JSON data, strings, or file paths.
///
/// ```swift
/// let jsonString = #"{"name":"dracula","colors":{}}"#
/// let theme = try ThemeLoader.load(json: jsonString)
/// let fileTheme = try ThemeLoader.load(path: "/path/to/theme.json")
/// ```
public enum ThemeLoader {
    /// Loads a theme from a JSON string.
    /// - Parameter json: A JSON string encoding a ``Theme``.
    /// - Returns: The decoded theme.
    public static func load(json: String) throws -> Theme {
        try load(data: Data(json.utf8))
    }

    /// Loads a theme from a file path.
    /// - Parameter path: The file system path to a JSON theme file.
    /// - Returns: The decoded theme.
    public static func load(path: String) throws -> Theme {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try load(data: data)
    }

    /// Loads a theme from raw JSON data.
    /// - Parameter data: The JSON data encoding a ``Theme``.
    /// - Returns: The decoded theme.
    public static func load(data: Data) throws -> Theme {
        try JSONDecoder().decode(Theme.self, from: data)
    }
}
