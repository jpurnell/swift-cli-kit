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
    /// How many password or public-key attempts one connection may make before the server
    /// closes it. Defaults to 6, OpenSSH's `MaxAuthTries` default.
    ///
    /// This bounds guessing per connection. It is not the per-account limit NIST SP 800-63B-4
    /// asks for, since a guesser can reconnect; that belongs to the identity layer behind the
    /// validator (SwiftIdentity's `FailureThrottle`, for one). The probe a client sends before
    /// its first real attempt does not count.
    public var maxAuthAttempts: Int

    /// Authentication modes supported by the SSH server.
    public enum AuthMode: Sendable {
        /// No authentication: every client is admitted, whatever it presents.
        ///
        /// Development only. A server in this mode is safe only for as long as nothing
        /// untrusted can reach its port — see ``SSHServer/init(host:port:hostKeySource:configuration:)``.
        case none
        /// Password-based authentication with a validation closure.
        /// The closure receives `(username, password)` and returns whether the credentials are valid.
        case password(@Sendable (String, String) -> Bool)
        /// Accept any public key (similar to Charm's Wish library).
        ///
        /// The client must prove it holds the private key, but every key is accepted: this
        /// identifies a client, it does not restrict who may connect.
        case publicKey
        /// An asynchronous verifier decides each password or public-key attempt, and may attach
        /// what it resolved to the session as ``SSHSession/verification``.
        ///
        /// The seam for an identity layer such as SwiftIdentity, whose checks are asynchronous.
        /// See ``SSHClientVerifier``.
        case verifier(any SSHClientVerifier)

        /// Whether this mode makes a client present a credential before it is admitted.
        ///
        /// `false` only for ``none``.
        public var authenticatesClients: Bool {
            switch self {
            case .none: return false
            case .password, .publicKey, .verifier: return true
            }
        }
    }

    /// Creates an SSH configuration with the given parameters.
    /// - Parameters:
    ///   - maxConnections: Maximum concurrent sessions. Defaults to 10.
    ///   - idleTimeout: Idle session timeout. Defaults to 300 seconds.
    ///   - maxAuthAttempts: Attempts per connection before it is closed. Defaults to 6.
    ///   - authMode: Authentication mode. Required: there is no default, so that a server
    ///     which authenticates nobody is always the result of writing `.none`.
    public init(
        maxConnections: Int = 10,
        idleTimeout: Duration = .seconds(300),
        maxAuthAttempts: Int = 6,
        authMode: AuthMode
    ) {
        self.maxConnections = maxConnections
        self.idleTimeout = idleTimeout
        self.maxAuthAttempts = maxAuthAttempts
        self.authMode = authMode
    }
}
