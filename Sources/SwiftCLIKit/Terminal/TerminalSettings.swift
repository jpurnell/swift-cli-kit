// TerminalSettings.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Persisted terminal preferences (color mode, render width, ASCII-only flag).
///
/// Settings are stored as JSON under `$XDG_CONFIG_HOME/<appName>/terminal.json`.
public struct TerminalSettings: Codable, Sendable {
    /// Controls whether ANSI color output is enabled.
    public enum ColorMode: String, Codable, Sendable {
        /// Detect automatically via `isatty` and `NO_COLOR`.
        case auto
        /// Always emit color escapes.
        case always
        /// Never emit color escapes.
        case never
    }

    /// Override width for rendering. A value of 0 means "use the actual terminal width".
    public var renderWidth: Int
    /// Whether to emit ANSI color codes.
    public var colorMode: ColorMode
    /// When `true`, use ASCII box-drawing characters instead of Unicode.
    public var asciiOnly: Bool

    /// Creates settings with the given values.
    /// - Parameter renderWidth: Override render width (0 = auto-detect).
    /// - Parameter colorMode: Color output mode. Defaults to `.auto`.
    /// - Parameter asciiOnly: Whether to restrict to ASCII characters. Defaults to `false`.
    public init(renderWidth: Int = 0, colorMode: ColorMode = .auto, asciiOnly: Bool = false) {
        self.renderWidth = renderWidth
        self.colorMode = colorMode
        self.asciiOnly = asciiOnly
    }

    /// Resolves whether color output should be enabled for the current environment.
    /// - Parameter isattyOverride: If provided, overrides the `isatty` check (useful for testing).
    /// - Returns: `true` if color escapes should be emitted.
    public func resolveColor(isattyOverride: Bool? = nil) -> Bool {
        switch colorMode {
        case .never:
            return false
        case .always:
            return true
        case .auto:
            if let override = isattyOverride {
                return override
            }
            if ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
                return false
            }
            #if canImport(Darwin) || canImport(Glibc)
            return isatty(STDOUT_FILENO) != 0
            #else
            return false
            #endif
        }
    }

    // MARK: - Persistence

    private static func configDirectory(appName: String) -> URL {
        let base: String
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = xdg
        } else {
            base = NSHomeDirectory() + "/.config"
        }
        return URL(fileURLWithPath: base).appendingPathComponent(appName)
    }

    private static func configFilePath(appName: String) -> URL {
        configDirectory(appName: appName).appendingPathComponent("terminal.json")
    }

    /// Loads settings from disk for the given application name.
    /// - Parameter appName: The application name used as the config subdirectory.
    /// - Returns: The decoded settings, or defaults if the file is missing or corrupt.
    public static func load(appName: String) -> TerminalSettings {
        let path = configFilePath(appName: appName)
        guard let data = try? Data(contentsOf: path) else { // silent: fallback to defaults when config file missing or unreadable
            return TerminalSettings()
        }
        guard let settings = try? JSONDecoder().decode(TerminalSettings.self, from: data) else { // silent: fallback to defaults on parse failure
            return TerminalSettings()
        }
        return settings
    }

    /// Persists these settings to disk as pretty-printed JSON.
    /// - Parameter appName: The application name used as the config subdirectory.
    /// - Throws: File-system errors if the directory or file cannot be written.
    public func save(appName: String) throws {
        let dir = TerminalSettings.configDirectory(appName: appName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = TerminalSettings.configFilePath(appName: appName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: path, options: .atomic)
    }
}
