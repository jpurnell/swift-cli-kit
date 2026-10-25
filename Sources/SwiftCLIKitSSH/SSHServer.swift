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
///
/// ## Transport
/// Key exchange is classical — curve25519 and the NIST curves — because that is all
/// swift-nio-ssh offers, and its key exchange is not pluggable (0.15.0, checked 2026-10-24).
/// Nothing here is post-quantum: a session recorded today, and any password typed into it,
/// could be decrypted by a future quantum computer. OpenSSH 10.1+ clients warn about this on
/// every connection. Where it matters, put the app behind OpenSSH or TLS, which already
/// negotiate hybrid post-quantum key exchange.
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
    ///
    /// The host key is how clients recognize the server. They record it on first connection and
    /// warn if it ever changes, which is what stops another machine from impersonating the
    /// server and collecting the passwords sent to it.
    public enum HostKeySource: Sendable {
        /// Generate an ephemeral Ed25519 key each time the server starts (development mode).
        ///
        /// Clients see a new key after every restart, so they cannot tell the server from an
        /// impersonator, and users learn to accept the warning that would have caught one.
        /// Use it only where nothing untrusted can reach the port. A server bound to another
        /// address with this source logs a warning at startup.
        case generateEphemeral
        /// Load the host key from the given file path.
        ///
        /// The file must be an unencrypted Ed25519 key in OpenSSH's format, readable and
        /// writable only by its owner, as OpenSSH requires of its own host keys:
        ///
        /// ```sh
        /// ssh-keygen -t ed25519 -N "" -f /path/to/ssh_host_ed25519_key
        /// ```
        ///
        /// A file that cannot be used stops ``SSHServer/start(sessionHandler:)`` with a
        /// ``SSHServer/HostKeyError`` before the server listens. It never falls back to an
        /// ephemeral key.
        case filePath(String)
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
    /// - Throws: ``SSHServer/HostKeyError`` if the host key file cannot be used, before
    ///   anything listens; otherwise any error from NIO bootstrap or binding.
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
        if case .generateEphemeral = hostKeySource, host != Self.loopbackHost {
            Self.logger.warning("SSH server on \(bound, privacy: .public) presents an ephemeral host key: clients cannot tell it from an impersonator across restarts. Use HostKeySource.filePath.")
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
    /// - Throws: ``SSHServer/HostKeyError`` if the host key file cannot be used, before
    ///   anything listens; otherwise any error from NIO bootstrap or binding.
    func bindListener(
        group: MultiThreadedEventLoopGroup,
        sessionHandler: @escaping @Sendable (SSHBackend, SSHSession) async throws -> Void
    ) async throws -> any Channel {
        let hostKey = try hostKeySource.privateKey()
        let mode = configuration.authMode
        let maxAttempts = configuration.maxAuthAttempts

        let bootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                // One authenticator per connection: it remembers whom it admitted, and every
                // session channel on the connection is that client's.
                let authDelegate = SSHAuthenticator(
                    mode: mode, maxAttempts: maxAttempts, disconnect: { channel.close(promise: nil) }
                )
                return channel.eventLoop.makeCompletedFuture {
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
                                            clientIdentity: authDelegate.admitted,
                                            verification: authDelegate.attachment,
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
///
/// One exists per connection. It records the identity it admitted, which the connection's
/// session channels carry as ``SSHSession/clientIdentity``, and it counts password and
/// public-key attempts: once ``SSHConfiguration/maxAuthAttempts`` have failed it closes the
/// connection, and refuses anything else without consulting the validator.
final class SSHAuthenticator: NIOSSHServerUserAuthenticationDelegate, Sendable {
    /// The mode this authenticator enforces.
    let mode: SSHConfiguration.AuthMode
    /// The identity admitted on this connection, once one has been.
    private let admittedIdentity: LockedState<SSHClientIdentity?> = LockedState(nil)
    /// Attempts allowed before the connection is closed.
    let maxAttempts: Int
    /// Attempts started so far, counted on arrival so that parallel requests can't overrun the cap.
    private let attempts = LockedState(0)
    /// Attempts that have failed so far.
    private let failures = LockedState(0)
    /// Closes the connection.
    private let disconnect: @Sendable () -> Void

    /// What a verifier attached when it admitted this connection.
    private let verifierAttachment: LockedState<SendableBox?> = LockedState(nil)

    /// What a verifier attached when it admitted this connection; `nil` otherwise.
    var attachment: (any Sendable)? {
        verifierAttachment.withLock { $0?.value }
    }

    /// Who this connection's client was admitted as; `nil` until a request succeeds.
    var admitted: SSHClientIdentity? {
        admittedIdentity.withLock { $0 }
    }

    /// Creates an authenticator for the given mode.
    /// - Parameters:
    ///   - mode: The authentication mode to enforce.
    ///   - maxAttempts: Attempts allowed before the connection is closed. Defaults to 6.
    ///   - disconnect: Closes the connection. Defaults to doing nothing, for tests of the mode alone.
    init(
        mode: SSHConfiguration.AuthMode,
        maxAttempts: Int = 6,
        disconnect: @escaping @Sendable () -> Void = {}
    ) {
        self.mode = mode
        self.maxAttempts = maxAttempts
        self.disconnect = disconnect
    }

    /// The methods offered to a client: only those the mode can admit.
    var supportedAuthenticationMethods: NIOSSHAvailableUserAuthenticationMethods {
        switch mode {
        case .none: return .all
        case .password: return .password
        case .publicKey: return .publicKey
        case .verifier(let verifier):
            var methods: NIOSSHAvailableUserAuthenticationMethods = []
            if verifier.methods.contains(.password) { methods.insert(.password) }
            if verifier.methods.contains(.publicKey) { methods.insert(.publicKey) }
            return methods
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
        case (.verifier, _):
            // Decided asynchronously, in `requestReceived`; never synchronously here.
            return false
        }
    }

    /// Answers an authentication request with the mode's decision.
    ///
    /// A password validator runs on `NIOThreadPool.singleton`, never on the connection's event
    /// loop: a validator worth having runs a deliberately slow KDF, and on the loop it would stall
    /// every other connection the loop serves. If the pool can't take the work, the answer is a
    /// refusal.
    func requestReceived(
        request: NIOSSHUserAuthenticationRequest,
        responsePromise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>
    ) {
        guard beginAttempt(request) else {
            responsePromise.succeed(.failure)
            disconnect()
            return
        }
        if case .verifier(let verifier) = mode {
            verify(request, with: verifier, promise: responsePromise)
            return
        }
        guard case .password(let validator) = mode, case .password(let offered) = request.request else {
            answer(request, admitted: admits(request), promise: responsePromise)
            return
        }
        let username = request.username
        let password = offered.password
        NIOThreadPool.singleton
            .runIfActive(eventLoop: responsePromise.futureResult.eventLoop) {
                validator(username, password)
            }
            .whenComplete { result in
                switch result {
                case .success(let admitted):
                    self.answer(request, admitted: admitted, promise: responsePromise)
                case .failure:
                    self.answer(request, admitted: false, promise: responsePromise)
                }
            }
    }

    /// Hands an attempt to an asynchronous verifier, off the event loop, and answers NIOSSH
    /// when it decides. A method the verifier didn't name is refused without asking it.
    private func verify(
        _ request: NIOSSHUserAuthenticationRequest,
        with verifier: any SSHClientVerifier,
        promise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>
    ) {
        let attempt: SSHAuthenticationAttempt
        switch request.request {
        case .password(let offered) where verifier.methods.contains(.password):
            attempt = SSHAuthenticationAttempt(username: request.username, evidence: .password, password: offered.password)
        case .publicKey(let offered) where verifier.methods.contains(.publicKey):
            attempt = SSHAuthenticationAttempt(username: request.username, evidence: .init(offered.publicKey))
        case .none, .password, .publicKey, .hostBased:
            answer(request, admitted: false, promise: promise)
            return
        }
        // Collapsed to one @Sendable closure so the task captures a single value.
        let decide: @Sendable () async -> Void = {
            let verdict = await verifier.verify(attempt)
            if verdict.admits, let value = verdict.attachment {
                self.verifierAttachment.withLock { $0 = SendableBox(value: value) }
            }
            self.answer(request, admitted: verdict.admits, promise: promise)
        }
        Task { await decide() }
    }

    /// Whether a request is a real attempt. The `none` probe a client sends first is not.
    private func counts(_ request: NIOSSHUserAuthenticationRequest) -> Bool {
        if case .none = request.request { return false }
        return true
    }

    /// Counts an attempt as it arrives.
    /// - Returns: `false` when the cap has already been reached and the request must be refused
    ///   unexamined.
    private func beginAttempt(_ request: NIOSSHUserAuthenticationRequest) -> Bool {
        guard counts(request) else { return true }
        return attempts.withLock { started -> Bool in
            guard started < maxAttempts else { return false }
            started += 1
            return true
        }
    }

    /// Records the identity if `admitted`, then completes NIOSSH's promise.
    private func answer(
        _ request: NIOSSHUserAuthenticationRequest,
        admitted: Bool,
        promise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>
    ) {
        guard admitted else {
            promise.succeed(.failure)
            if counts(request), failures.withLock({ $0 += 1; return $0 }) >= maxAttempts {
                disconnect()
            }
            return
        }
        admittedIdentity.withLock { $0 = SSHClientIdentity(admitted: request) }
        promise.succeed(.success)
    }
}

/// Holds an existential so it can sit in a ``LockedState``, whose state must be `Sendable`.
struct SendableBox: Sendable {
    /// The held value.
    let value: any Sendable
}
