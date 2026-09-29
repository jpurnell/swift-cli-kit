// AccessibilityLabel.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// A structured accessibility description for a widget, containing role, label, value, hint, and child count.
///
/// Use ``formatted(verbosity:)`` to produce a human-readable announcement string at the desired detail level.
public struct AccessibilityLabel: Sendable, Equatable {
    /// The semantic role of the widget.
    public var role: AccessibilityRole
    /// A short description of the widget.
    public var label: String
    /// The current value, if applicable (e.g. "75%" for a gauge).
    public var value: String?
    /// A usage hint for screen reader users.
    public var hint: String?
    /// The number of child elements, if applicable.
    public var childCount: Int?

    /// Creates an accessibility label.
    /// - Parameters:
    ///   - role: The semantic role.
    ///   - label: A short description.
    ///   - value: The current value (default: nil).
    ///   - hint: A usage hint (default: nil).
    ///   - childCount: Number of child elements (default: nil).
    public init(
        role: AccessibilityRole,
        label: String,
        value: String? = nil,
        hint: String? = nil,
        childCount: Int? = nil
    ) {
        self.role = role
        self.label = label
        self.value = value
        self.hint = hint
        self.childCount = childCount
    }

    /// Formats the label for announcement at the given verbosity level.
    /// - Parameter verbosity: The detail level for the output string.
    /// - Returns: A human-readable announcement string.
    public func formatted(verbosity: AccessibilitySettings.Verbosity) -> String {
        switch verbosity {
        case .minimal:
            return "\(role.rawValue): \(label)"
        case .standard:
            var result = "\(role.rawValue): \(label)"
            if let value { result += ". \(value)" }
            return result
        case .verbose:
            var result = "\(role.rawValue): \(label)"
            if let value { result += ". \(value)" }
            if let hint { result += ". \(hint)" }
            if let childCount { result += ". \(childCount) items" }
            return result
        }
    }
}
