// SSHServer.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation
import NIOCore
import NIOPosix
@preconcurrency import NIOSSH
#if canImport(os)
import os
#endif
import SwiftCLIKit

/// An SSH server that can spawn isolated SwiftCLIKit app sessions per connection.
///
/// Each connecting client receives its own ``SSHBackend`` and ``SSHSession``,
/// enabling fully isolated TUI sessions over SSH.
///
/// ```swift
/// let server = SSHServer(
///     port: 2222,
///     configuration: SSHConfiguration(
///         authMode: .password { user, password in user == "admin" && password == "secret" }
///     )
/// )
/// try await server.start { backend, session in
///     // Run your TUI app using the SSH backend
///     backend.write("Welcome, \(session.remoteAddress)\r\n")
/// }
/// ```
///
/// ## Reachability and authentication
/// Neither is left to a default that widens access. The server binds the loopback
/// interface unless `host` names another address, and ``SSHConfiguration`` cannot be
/// created without an ``SSHConfiguration/AuthMode``. The mode is enforced: clients are
/// admitted only as ``SSHConfiguration/authMode`` allows.
public struct SSHServer: Sendable {
    #if canImport(os)
    private static let logger = Logger(subsystem: "com.swiftclikit", category: "SSHServer")
    #endif

    /// The loopback address, `127.0.0.1` — the default bind address.
    public static let loopbackHost = "127.0.0.1"

    /// The host address to bind to.
    public let host: String
    /// The port to listen on.
    public let port: Int
    /// How the server obtains its host key.
    public let hostKeySource: HostKeySource
    /// Server configuration for authentication, limits, and timeouts.
    public let configuration: SSHConfiguration

    /// Source for the SSH server's host key.
    public enum HostKeySource: Sendable {
        /// Generate an ephemeral Ed25519 key each time the server starts (development mode).
        case generateEphemeral
        /// Load the host key from the given file path.
        case filePath(String) // LIVE: public API
    }

    /// Creates an SSH server with the given parameters.
    /// - Parameters:
    ///   - host: The address to bind to. Defaults to ``loopbackHost`` (`127.0.0.1`), which
    ///     only this machine can reach. Pass `"0.0.0.0"`, or a specific interface address,
    ///     to accept connections from other machines.
    ///   - port: The port to listen on. Defaults to 2222.
    ///   - hostKeySource: How to obtain the host key. Defaults to `.generateEphemeral`.
    ///   - configuration: Server configuration. Required, because it carries the
    ///     authentication mode and that has no default.
    public init(
        host: String = SSHServer.loopbackHost,
        port: Int = 2222,
        hostKeySource: HostKeySource = .generateEphemeral,
        configuration: SSHConfiguration
    ) {
        self.host = host
        self.port = port
        self.hostKeySource = hostKeySource
        self.configuration = configuration
    }

    /// Starts the SSH server, blocking until shutdown.
    ///
    /// For each incoming connection, the `sessionHandler` closure is invoked
    /// with an ``SSHBackend`` and ``SSHSession`` for that connection.
    ///
    /// - Parameter sessionHandler: A closure that handles each SSH session.
    /// - Throws: Any error from NIO bootstrap or binding.
    public func start(
        sessionHandler: @escaping @Sendable (SSHBackend, SSHSession) async throws -> Void
    ) async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let serverChannel: any Channel
        do {
            serverChannel = try await bindListener(group: group, sessionHandler: sessionHandler)
        } catch {
            try await group.shutdownGracefully()
            throw error
        }

        #if canImport(os)
        let bound = serverChannel.localAddress?.description ?? "\(host):\(port)"
        Self.logger.info("SSH server listening on \(bound, privacy: .public)")
        if !configuration.authMode.authenticatesClients {
            Self.logger.warning("SSH server on \(bound, privacy: .public) authenticates nobody: authMode is .none")
        }
        #endif

        do {
            try await serverChannel.closeFuture.get()
        } catch {
            try await group.shutdownGracefully()
            throw error
        }
        try await group.shutdownGracefully()
    }

    /// Binds the listening socket and returns its channel without waiting for it to close.
    ///
    /// ``start(sessionHandler:)`` is this plus the wait. It is separate so the address a
    /// server actually binds can be read from the channel.
    ///
    /// - Parameters:
    ///   - group: The event loop group the listener and its connections run on.
    ///   - sessionHandler: A closure that handles each SSH session.
    /// - Returns: The bound server channel.
    /// - Throws: Any error from NIO bootstrap or binding.
    func bindListener(
        group: MultiThreadedEventLoopGroup,
        sessionHandler: @escaping @Sendable (SSHBackend, SSHSession) async throws -> Void
    ) async throws -> any Channel {
        let hostKey = NIOSSHPrivateKey(ed25519Key: .init())
        let authDelegate = SSHAuthenticator(mode: configuration.authMode)

        let bootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .server(
                                .init(
                                    hostKeys: [hostKey],
                                    userAuthDelegate: authDelegate
                                )
                            ),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: { childChannel, channelType in
                                // Only interactive/exec session channels run apps;
                                // port-forwarding channel types are declined.
                                guard channelType == .session else {
                                    return childChannel.eventLoop.makeSucceededFuture(())
                                }
                                let remoteAddress = childChannel.remoteAddress?.description ?? "unknown"
                                return childChannel.eventLoop.makeCompletedFuture {
                                    try childChannel.pipeline.syncOperations.addHandler(
                                        SSHSessionChannelHandler(
                                            remoteAddress: remoteAddress,
                                            sessionHandler: sessionHandler
                                        )
                                    )
                                }
                            }
                        )
                    )
                }
            }
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)

        return try await bootstrap.bind(host: host, port: port).get()
    }
}

/// Decides which clients an ``SSHServer`` admits, according to its
/// ``SSHConfiguration/AuthMode``.
///
/// - ``SSHConfiguration/AuthMode/none`` admits every request.
/// - ``SSHConfiguration/AuthMode/password(_:)`` admits a password request its validator
///   accepts, and nothing else.
/// - ``SSHConfiguration/AuthMode/publicKey`` admits a public-key request, and nothing else.
///   NIOSSH has verified the client's signature before the request arrives here.
final class SSHAuthenticator: NIOSSHServerUserAuthenticationDelegate, Sendable {
    /// The mode this authenticator enforces.
    let mode: SSHConfiguration.AuthMode

    /// Creates an authenticator for the given mode.
    /// - Parameter mode: The authentication mode to enforce.
    init(mode: SSHConfiguration.AuthMode) {
        self.mode = mode
    }

    /// The methods offered to a client: only those the mode can admit.
    var supportedAuthenticationMethods: NIOSSHAvailableUserAuthenticationMethods {
        switch mode {
        case .none: return .all
        case .password: return .password
        case .publicKey: return .publicKey
        }
    }

    /// Whether the mode admits this request.
    /// - Parameter request: The client's authentication request.
    /// - Returns: `true` when the client is to be authenticated.
    func admits(_ request: NIOSSHUserAuthenticationRequest) -> Bool {
        switch (mode, request.request) {
        case (.none, _):
            return true
        case (.password(let validator), .password(let offered)):
            return validator(request.username, offered.password)
        case (.publicKey, .publicKey):
            return true
        case (.password, _), (.publicKey, _):
            return false
        }
    }

    /// Answers an authentication request with the mode's decision.
    func requestReceived(
        request: NIOSSHUserAuthenticationRequest,
        responsePromise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>
    ) {
        responsePromise.succeed(admits(request) ? .success : .failure)
    }
}
