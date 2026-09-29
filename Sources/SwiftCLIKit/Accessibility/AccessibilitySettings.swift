// AccessibilitySettings.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Global accessibility configuration controlling whether announcements are emitted and at what verbosity.
public struct AccessibilitySettings: Sendable {
    /// Whether accessibility announcements are enabled.
    public var isEnabled: Bool
    /// The verbosity level for announcements.
    public var verbosity: Verbosity

    /// The detail level for accessibility announcements.
    public enum Verbosity: Sendable {
        /// Role and label only.
        case minimal
        /// Role, label, and value.
        case standard
        /// Role, label, value, hint, and child count.
        case verbose
    }

    /// Default settings with accessibility disabled at standard verbosity.
    public static let `default` = AccessibilitySettings(isEnabled: false, verbosity: .standard)

    /// Creates accessibility settings.
    /// - Parameters:
    ///   - isEnabled: Whether announcements are enabled (default: false).
    ///   - verbosity: The verbosity level (default: .standard).
    public init(isEnabled: Bool = false, verbosity: Verbosity = .standard) {
        self.isEnabled = isEnabled
        self.verbosity = verbosity
    }
}
