// SessionManager.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation
import SwiftCLIKit

/// Manages active SSH sessions, enforcing connection limits and coordinating lifecycle.
///
/// ``SessionManager`` is an actor that safely tracks concurrent sessions
/// and enforces the configured maximum connection limit.
///
/// ```swift
/// let manager = SessionManager(maxConnections: 10)
/// let session = SSHSession(id: UUID().uuidString, remoteAddress: "10.0.1.50")
/// let accepted = await manager.addSession(session)
/// ```
public actor SessionManager {
    private var sessions: [String: SSHSession] = [:]
    private let maxConnections: Int

    /// Creates a session manager with the given connection limit.
    /// - Parameter maxConnections: Maximum concurrent sessions allowed. Defaults to 10.
    public init(maxConnections: Int = 10) {
        self.maxConnections = maxConnections
    }

    /// Attempts to add a session. Returns `true` if accepted, `false` if at capacity.
    /// - Parameter session: The session to register.
    /// - Returns: Whether the session was accepted.
    public func addSession(_ session: SSHSession) -> Bool {
        guard sessions.count < maxConnections else { return false }
        sessions[session.id] = session
        return true
    }

    /// Removes a session by its identifier.
    /// - Parameter id: The session ID to remove.
    public func removeSession(id: String) {
        sessions.removeValue(forKey: id)
    }

    /// The number of currently active sessions.
    public func activeSessionCount() -> Int {
        sessions.count
    }

    /// Returns all currently active sessions.
    public func allSessions() -> [SSHSession] {
        Array(sessions.values)
    }
}
