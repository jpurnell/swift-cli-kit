// AccessibilityAnnouncer.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Emits accessibility announcements to an output channel (stderr or custom handler).
///
/// The announcer respects ``AccessibilitySettings`` and silently drops messages when disabled.
public struct AccessibilityAnnouncer: Sendable {
    /// The output destination for announcements.
    public enum OutputChannel: Sendable {
        /// Write to standard error.
        case stderr
        /// Write to a custom handler closure.
        case custom(@Sendable (String) -> Void)
    }

    private let channel: OutputChannel
    private let settings: AccessibilitySettings

    /// Creates an announcer.
    /// - Parameters:
    ///   - channel: The output channel (default: .stderr).
    ///   - settings: The accessibility settings (default: .default).
    public init(channel: OutputChannel = .stderr, settings: AccessibilitySettings = .default) {
        self.channel = channel
        self.settings = settings
    }

    /// Announces a free-form message.
    /// - Parameter message: The message to announce.
    public func announce(_ message: String) {
        guard settings.isEnabled else { return }
        output(message)
    }

    /// Announces a focus change between widgets.
    /// - Parameters:
    ///   - previousID: The identifier of the previously focused widget, or nil.
    ///   - currentID: The identifier of the newly focused widget, or nil.
    ///   - label: The accessibility label of the newly focused widget, or nil.
    public func focusChanged(from previousID: String?, to currentID: String?, label: AccessibilityLabel?) {
        guard settings.isEnabled else { return }
        var parts: [String] = []
        if let currentID { parts.append("Focus: \(currentID)") }
        if let label { parts.append(label.formatted(verbosity: settings.verbosity)) }
        guard !parts.isEmpty else { return }
        output(parts.joined(separator: ". "))
    }

    /// Announces that a widget's value has changed.
    /// - Parameters:
    ///   - widgetID: The identifier of the widget that changed.
    ///   - label: The updated accessibility label.
    public func valueChanged(widgetID: String, label: AccessibilityLabel) {
        guard settings.isEnabled else { return }
        output("Updated \(widgetID): \(label.formatted(verbosity: settings.verbosity))")
    }

    private func output(_ message: String) {
        switch channel {
        case .stderr:
            FileHandle.standardError.write(Data((message + "\n").utf8))
        case .custom(let handler):
            handler(message)
        }
    }
}
