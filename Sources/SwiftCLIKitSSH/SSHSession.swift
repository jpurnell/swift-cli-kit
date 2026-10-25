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
    /// Who the server admitted on this connection, and with what; `nil` for a session not made
    /// by an ``SSHServer``.
    public var clientIdentity: SSHClientIdentity?
    /// What an ``SSHClientVerifier`` attached when it admitted the connection; `nil` under any
    /// other mode, or when it attached nothing.
    public var verification: (any Sendable)?

    /// Creates a session with the given metadata.
    /// - Parameters:
    ///   - id: Unique session identifier.
    ///   - remoteAddress: The remote client address.
    ///   - terminalSize: The client's terminal dimensions. Defaults to 80x24.
    ///   - clientIdentity: Who was admitted on the connection. Defaults to `nil`.
    ///   - verification: What the connection's verifier attached. Defaults to `nil`.
    public init(
        id: String,
        remoteAddress: String,
        terminalSize: TerminalSize = TerminalSize(columns: 80, rows: 24),
        clientIdentity: SSHClientIdentity? = nil,
        verification: (any Sendable)? = nil
    ) {
        self.verification = verification
        self.id = id
        self.remoteAddress = remoteAddress
        self.terminalSize = terminalSize
        self.clientIdentity = clientIdentity
        self.connectedAt = Date()
    }
}
