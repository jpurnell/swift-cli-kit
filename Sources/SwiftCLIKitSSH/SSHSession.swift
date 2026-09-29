// SSHSession.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation
import SwiftCLIKit

/// Metadata for a single SSH connection.
///
/// Each connected client is represented by an ``SSHSession`` with a unique
/// identifier, remote address, terminal dimensions, and connection timestamp.
///
/// ```swift
/// let session = SSHSession(
///     id: UUID().uuidString,
///     remoteAddress: "10.0.1.50"
/// )
/// print(session.connectedAt)
/// ```
public struct SSHSession: Sendable, Identifiable {
    /// Unique identifier for this session.
    public var id: String
    /// The remote client's IP address or hostname.
    public var remoteAddress: String
    /// The client's reported terminal dimensions.
    public var terminalSize: TerminalSize
    /// When the client connected.
    public var connectedAt: Date

    /// Creates a session with the given metadata.
    /// - Parameters:
    ///   - id: Unique session identifier.
    ///   - remoteAddress: The remote client address.
    ///   - terminalSize: The client's terminal dimensions. Defaults to 80x24.
    public init(
        id: String,
        remoteAddress: String,
        terminalSize: TerminalSize = TerminalSize(columns: 80, rows: 24)
    ) {
        self.id = id
        self.remoteAddress = remoteAddress
        self.terminalSize = terminalSize
        self.connectedAt = Date()
    }
}
