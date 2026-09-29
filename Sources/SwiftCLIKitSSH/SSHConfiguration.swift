// SSHConfiguration.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Configuration for the SSH server's security and resource policies.
///
/// Controls authentication, connection limits, and idle timeouts for an
/// ``SSHServer`` instance.
///
/// ```swift
/// let config = SSHConfiguration(
///     maxConnections: 32,
///     idleTimeout: .seconds(600),
///     authMode: .password { user, pass in user == "admin" && pass == "secret" }
/// )
/// ```
public struct SSHConfiguration: Sendable {
    /// Maximum number of concurrent SSH sessions.
    public var maxConnections: Int
    /// Duration after which an idle session is disconnected.
    public var idleTimeout: Duration
    /// The authentication mode for incoming connections.
    public var authMode: AuthMode

    /// Authentication modes supported by the SSH server.
    public enum AuthMode: Sendable {
        /// No authentication (development only).
        case none
        /// Password-based authentication with a validation closure.
        /// The closure receives `(username, password)` and returns whether the credentials are valid.
        case password(@Sendable (String, String) -> Bool) // LIVE: public API
        /// Accept any public key (similar to Charm's Wish library).
        case publicKey // LIVE: public API
    }

    /// Creates an SSH configuration with the given parameters.
    /// - Parameters:
    ///   - maxConnections: Maximum concurrent sessions. Defaults to 10.
    ///   - idleTimeout: Idle session timeout. Defaults to 300 seconds.
    ///   - authMode: Authentication mode. Defaults to `.none`.
    public init(
        maxConnections: Int = 10,
        idleTimeout: Duration = .seconds(300),
        authMode: AuthMode = .none
    ) {
        self.maxConnections = maxConnections
        self.idleTimeout = idleTimeout
        self.authMode = authMode
    }
}
