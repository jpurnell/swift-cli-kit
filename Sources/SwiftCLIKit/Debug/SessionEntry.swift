// SessionEntry.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A single recorded entry in a session replay file.
///
/// Each entry captures a timestamped event or application message,
/// enabling deterministic replay of an entire session through the
/// MVU update function.
///
/// ```swift
/// enum MyMessage: Sendable, Codable { case increment }
///
/// let entry = SessionEntry<MyMessage>(
///     timestamp: 1.5,
///     kind: .message(.increment)
/// )
/// ```
public struct SessionEntry<Message: Codable & Sendable>: Codable, Sendable {
    /// Seconds elapsed since the session recording began.
    public var timestamp: Double

    /// The type of entry recorded at this timestamp.
    public var kind: EntryKind

    /// Distinguishes between event snapshots and application messages.
    public enum EntryKind: Codable, Sendable {
        /// A keyboard event captured during the session.
        case keyEvent(KeyEventSnapshot)
        /// A terminal resize event with the new dimensions.
        case resizeEvent(width: Int, height: Int)
        /// An application-level message processed by the update function.
        case message(Message)
    }

    /// Creates a new session entry.
    /// - Parameters:
    ///   - timestamp: Seconds since session start.
    ///   - kind: The type of entry to record.
    public init(timestamp: Double, kind: EntryKind) {
        self.timestamp = timestamp
        self.kind = kind
    }
}

/// A serializable snapshot of a key event for session recording.
///
/// Captures a human-readable description of the key that was pressed,
/// suitable for replay and debugging inspection.
public struct KeyEventSnapshot: Codable, Sendable, Equatable {
    /// A human-readable description of the key (e.g. "a", "enter", "ctrl+c").
    public var description: String

    /// Creates a new key event snapshot.
    /// - Parameter description: Human-readable key description.
    public init(description: String) {
        self.description = description
    }
}
