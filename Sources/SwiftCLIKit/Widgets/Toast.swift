// Toast.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Severity level for a toast notification, controlling visual styling.
public enum ToastSeverity: Sendable, Equatable, CaseIterable {
    case info
    case success
    case warning
    case error

    /// The color associated with this severity level.
    public var color: Color {
        switch self {
        case .info: return .ansi8(.cyan)
        case .success: return .ansi8(.green)
        case .warning: return .ansi8(.yellow)
        case .error: return .ansi8(.red)
        }
    }
}

/// A single transient notification message.
///
/// ```swift
/// let toast = Toast(message: "File saved", severity: .success)
/// ```
public struct Toast: Sendable, Identifiable, Equatable {
    /// Unique identifier for this toast.
    public var id: String
    /// The notification message.
    public var message: String
    /// The severity level.
    public var severity: ToastSeverity
    /// How long before auto-dismissal.
    public var duration: Duration
    /// When this toast was created.
    public var createdAt: ContinuousClock.Instant

    /// Creates a toast with an auto-generated UUID-based identifier.
    /// - Parameters:
    ///   - message: The notification text.
    ///   - severity: The severity level.
    ///   - duration: Auto-dismiss duration.
    ///   - createdAt: Creation timestamp (defaults to now).
    public init(
        message: String,
        severity: ToastSeverity = .info,
        duration: Duration = .seconds(3),
        createdAt: ContinuousClock.Instant = ContinuousClock.now
    ) {
        self.id = UUID().uuidString
        self.message = message
        self.severity = severity
        self.duration = duration
        self.createdAt = createdAt
    }

    /// Whether this toast has expired relative to the given time.
    /// - Parameter now: The reference time to check against.
    /// - Returns: `true` if the toast has been alive longer than its duration.
    public func isExpired(at now: ContinuousClock.Instant) -> Bool {
        now >= createdAt + duration
    }

    /// Returns whether two toasts are equal by comparing their identity, message, severity, duration, and creation time.
    public static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
            && lhs.message == rhs.message
            && lhs.severity == rhs.severity
            && lhs.duration == rhs.duration
            && lhs.createdAt == rhs.createdAt
    }
}
