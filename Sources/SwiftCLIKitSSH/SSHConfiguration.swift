// SSHConfiguration.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Configuration for the SSH server's security and resource policies.
///
/// Controls authentication, connection limits, and idle timeouts for an
/// ``SSHServer`` instance.
///
/// The authentication mode has no default. A configuration cannot be written without
/// saying who is allowed in, so an unauthenticated server is never something a caller
/// gets by leaving an argument out.
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
        /// No authentication: every client is admitted, whatever it presents.
        ///
        /// Development only. A server in this mode is safe only for as long as nothing
        /// untrusted can reach its port — see ``SSHServer/init(host:port:hostKeySource:configuration:)``.
        case none
        /// Password-based authentication with a validation closure.
        /// The closure receives `(username, password)` and returns whether the credentials are valid.
        case password(@Sendable (String, String) -> Bool) // LIVE: public API
        /// Accept any public key (similar to Charm's Wish library).
        ///
        /// The client must prove it holds the private key, but every key is accepted: this
        /// identifies a client, it does not restrict who may connect.
        case publicKey // LIVE: public API

        /// Whether this mode makes a client present a credential before it is admitted.
        ///
        /// `false` only for ``none``.
        public var authenticatesClients: Bool {
            switch self {
            case .none: return false
            case .password, .publicKey: return true
            }
        }
    }

    /// Creates an SSH configuration with the given parameters.
    /// - Parameters:
    ///   - maxConnections: Maximum concurrent sessions. Defaults to 10.
    ///   - idleTimeout: Idle session timeout. Defaults to 300 seconds.
    ///   - authMode: Authentication mode. Required: there is no default, so that a server
    ///     which authenticates nobody is always the result of writing `.none`.
    public init(
        maxConnections: Int = 10,
        idleTimeout: Duration = .seconds(300),
        authMode: AuthMode
    ) {
        self.maxConnections = maxConnections
        self.idleTimeout = idleTimeout
        self.authMode = authMode
    }
}
