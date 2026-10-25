// SSHClientIdentityTests.swift
// SwiftCLIKitSSH

import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
import SwiftCLIKit
@testable import SwiftCLIKitSSH

/// Offers one private key, optionally with its certificate, then gives up.
private final class OfferKey: NIOSSHClientUserAuthenticationDelegate, Sendable {
    let username: String
    let key: NIOSSHPrivateKey
    let certificate: NIOSSHCertifiedPublicKey?
    private let offered = LockedState(false)

    init(username: String, key: NIOSSHPrivateKey, certificate: NIOSSHCertifiedPublicKey? = nil) {
        self.username = username
        self.key = key
        self.certificate = certificate
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        let first = offered.withLock { done -> Bool in
            defer { done = true }
            return !done
        }
        guard first, availableMethods.contains(.publicKey) else {
            nextChallengePromise.succeed(nil)
            return
        }
        let privateKey: NIOSSHUserAuthenticationOffer.Offer.PrivateKey
        if let certificate {
            privateKey = .init(privateKey: key, certifiedKey: certificate)
        } else {
            privateKey = .init(privateKey: key)
        }
        nextChallengePromise.succeed(.init(username: username, serviceName: "", offer: .privateKey(privateKey)))
    }
}

/// Accepts any host key: these tests are about the client's identity, not the server's.
private final class AcceptHostKey: NIOSSHClientServerAuthenticationDelegate, Sendable {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

/// Collects what each session handler saw, keyed by the username it was admitted as.
private final class SeenIdentities: Sendable {
    private let state: LockedState<[String: SSHClientIdentity]> = LockedState([:])

    func record(_ identity: SSHClientIdentity?) {
        guard let identity else { return }
        state.withLock { $0[identity.username] = identity }
    }

    var values: [String: SSHClientIdentity] {
        state.withLock { $0 }
    }
}

/// An app can only keep its own allow-list if it can see who connected. Until 2.2.0,
/// `SSHSession` carried an address and a terminal size, and nothing about the credential.
@Suite("SSH client identity")
struct SSHClientIdentityTests {

    // MARK: - Fixtures

    private static func fixtureURL(_ name: String) throws -> URL {
        try #require(
            Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"),
            "fixture \(name) is missing from the test bundle"
        )
    }

    private static func fixtureLine(_ name: String) throws -> String {
        try String(contentsOf: fixtureURL(name), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first two fields of an OpenSSH public key line: type and base64, without the comment.
    private static func withoutComment(_ line: String) -> String {
        line.split(separator: " ").prefix(2).joined(separator: " ")
    }

    /// The fixture user's private key, copied to an owner-only file and read by the same
    /// loader the server uses for host keys (both are `ssh-keygen -t ed25519 -N ""` files).
    private static func userKey(_ name: String = "user_ed25519") throws -> NIOSSHPrivateKey {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHClientIdentityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: fixtureURL(name), to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        return try OpenSSHHostKeyFile(path: destination.path).load()
    }

    private static func certificate() throws -> NIOSSHCertifiedPublicKey {
        let key = try NIOSSHPublicKey(openSSHPublicKey: fixtureLine("user_ed25519-cert.pub"))
        return try #require(NIOSSHCertifiedPublicKey(key))
    }

    private static func request(
        _ user: String,
        _ request: NIOSSHUserAuthenticationRequest.Request
    ) -> NIOSSHUserAuthenticationRequest {
        NIOSSHUserAuthenticationRequest(username: user, serviceName: "ssh-connection", request: request)
    }

    /// Runs one request through `requestReceived`, as NIOSSH would, and reports whether it was
    /// answered with success.
    private static func answer(
        _ authenticator: SSHAuthenticator,
        _ request: NIOSSHUserAuthenticationRequest
    ) throws -> Bool {
        // A real loop, not an embedded one: password validation completes from the thread pool.
        let promise = MultiThreadedEventLoopGroup.singleton.next().makePromise(of: NIOSSHUserAuthenticationOutcome.self)
        authenticator.requestReceived(request: request, responsePromise: promise)
        if case .success = try promise.futureResult.wait() { return true }
        return false
    }

    // MARK: - The evidence each method leaves

    @Test("A password sign-in is recorded as a password, and the password is not kept")
    func passwordEvidence() throws {
        let authenticator = SSHAuthenticator(mode: .password { _, password in password == "correct horse" })
        let outcome = try Self.answer(authenticator, Self.request("ada", .password(.init(password: "correct horse"))))
        #expect(outcome)
        let identity = try #require(authenticator.admitted)
        #expect(identity == SSHClientIdentity(username: "ada", evidence: .password))
        #expect(identity.evidence.kind == "password")
        #expect(identity.evidence.openSSHPublicKey == nil)
        #expect(!String(describing: identity).contains("correct horse"))
        #expect(!String(reflecting: identity).contains("correct horse"))
    }

    @Test("A public-key sign-in records the key in OpenSSH form")
    func publicKeyEvidence() throws {
        let key = try Self.userKey()
        let authenticator = SSHAuthenticator(mode: .publicKey)
        let outcome = try Self.answer(authenticator, Self.request("ada", .publicKey(.init(publicKey: key.publicKey))))
        #expect(outcome)
        let identity = try #require(authenticator.admitted)
        #expect(identity.username == "ada")
        #expect(identity.evidence.kind == "public-key")
        #expect(identity.evidence.openSSHPublicKey == Self.withoutComment(try Self.fixtureLine("user_ed25519.pub")))
        #expect(identity.evidence.certificate == nil)
    }

    @Test("A certificate sign-in records what ssh-keygen -L reads from the certificate")
    func certificateEvidence() throws {
        // Expected values: `TZ=UTC ssh-keygen -L -f user_ed25519-cert.pub`, kept beside the
        // fixture as user_ed25519-cert.txt.
        let certificate = try Self.certificate()
        let authenticator = SSHAuthenticator(mode: .publicKey)
        let outcome = try Self.answer(
            authenticator, Self.request("alice", .publicKey(.init(publicKey: NIOSSHPublicKey(certificate))))
        )
        #expect(outcome)
        let identity = try #require(authenticator.admitted)
        #expect(identity.evidence.kind == "certificate")
        let summary = try #require(identity.evidence.certificate)
        #expect(summary.keyID == "fixture-key-id")
        #expect(summary.principals == ["alice", "ops"])
        #expect(summary.validAfter == Date(timeIntervalSince1970: 1_767_225_600))   // 2026-01-01T00:00:00Z
        #expect(summary.validBefore == Date(timeIntervalSince1970: 2_082_758_400))  // 2036-01-01T00:00:00Z
        #expect(summary.signingCAOpenSSH == Self.withoutComment(try Self.fixtureLine("user_ca_ed25519.pub")))
        #expect(identity.evidence.openSSHPublicKey == Self.withoutComment(try Self.fixtureLine("user_ed25519-cert.pub")))
    }

    @Test("A client admitted by .none is recorded with no evidence")
    func noneEvidence() throws {
        let authenticator = SSHAuthenticator(mode: .none)
        #expect(try Self.answer(authenticator, Self.request("guest", .none)))
        #expect(authenticator.admitted == SSHClientIdentity(username: "guest", evidence: .none))
        #expect(SSHClientIdentity.Evidence.none.kind == "none")
    }

    @Test("A refused request records nothing")
    func refusalRecordsNothing() throws {
        let authenticator = SSHAuthenticator(mode: .password { _, _ in false })
        #expect(try !Self.answer(authenticator, Self.request("ada", .password(.init(password: "wrong")))))
        #expect(authenticator.admitted == nil)
    }

    @Test("A session made without an identity has none")
    func sessionDefault() {
        #expect(SSHSession(id: "s", remoteAddress: "10.0.0.1").clientIdentity == nil)
        let identity = SSHClientIdentity(username: "ada", evidence: .password)
        #expect(SSHSession(id: "s", remoteAddress: "10.0.0.1", clientIdentity: identity).clientIdentity == identity)
    }

    // MARK: - Over the wire

    /// Connects with `delegate`, opens a session channel, asks for a shell, and waits for the
    /// server to close it.
    private static func connect(
        port: Int, group: any EventLoopGroup, delegate: OfferKey, deadline: TimeAmount = .seconds(10)
    ) async throws {
        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .client(.init(userAuthDelegate: delegate, serverAuthDelegate: AcceptHostKey())),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                }
            }
            .connect(host: "127.0.0.1", port: port)
            .get()
        // A refused sign-in leaves the session channel pending forever; this turns that into
        // a failure instead of a hang.
        let opened = client.eventLoop.makePromise(of: Channel.self)
        let timer = client.eventLoop.scheduleTask(in: deadline) {
            opened.fail(ChannelError.connectTimeout(deadline))
            client.close(promise: nil)
        }
        defer { timer.cancel() }
        client.eventLoop.execute {
            do {
                let handler = try client.pipeline.syncOperations.handler(type: NIOSSHHandler.self)
                handler.createChannel(opened, channelType: .session) { child, _ in
                    child.eventLoop.makeSucceededVoidFuture()
                }
            } catch {
                opened.fail(error)
            }
        }
        let session = try await opened.futureResult.get()
        try await session.triggerUserOutboundEvent(SSHChannelRequestEvent.ShellRequest(wantReply: false)).get()
        try await session.closeFuture.get()
        try await client.close()
    }

    @Test("A key admitted over the wire reaches the session handler")
    func keyReachesSession() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let seen = SeenIdentities()
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .publicKey))
        let listener = try await server.bindListener(group: group) { _, session in
            seen.record(session.clientIdentity)
        }
        let port = try #require(listener.localAddress?.port)
        let key = try Self.userKey()
        try await Self.connect(port: port, group: group, delegate: OfferKey(username: "ada", key: key))
        try await listener.close()
        try await group.shutdownGracefully()
        #expect(seen.values["ada"]?.evidence.openSSHPublicKey == String(openSSHPublicKey: key.publicKey))
    }

    @Test("Two concurrent connections each see their own identity")
    func concurrentConnectionsAreSeparate() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        let seen = SeenIdentities()
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .publicKey))
        let listener = try await server.bindListener(group: group) { _, session in
            seen.record(session.clientIdentity)
        }
        let port = try #require(listener.localAddress?.port)

        let adaKey = try Self.userKey()
        let graceKey = try Self.userKey("host_ed25519")  // any second ssh-keygen key will do
        async let first: Void = Self.connect(port: port, group: group, delegate: OfferKey(username: "ada", key: adaKey))
        async let second: Void = Self.connect(port: port, group: group, delegate: OfferKey(username: "grace", key: graceKey))
        _ = try await (first, second)
        try await listener.close()
        try await group.shutdownGracefully()

        let values = seen.values
        #expect(values.count == 2)
        #expect(values["ada"]?.evidence.openSSHPublicKey == Self.withoutComment(try Self.fixtureLine("user_ed25519.pub")))
        #expect(values["grace"]?.evidence.openSSHPublicKey == Self.withoutComment(try Self.fixtureLine("host_ed25519.pub")))
    }

    /// swift-nio-ssh's server parses a user-auth request only for the four plain key
    /// algorithms (`NIOSSHPublicKey.knownAlgorithms`, unchanged on main as of 2026-10-24), so a
    /// certificate sign-in is refused before ``SSHAuthenticator`` is asked. Certificate evidence
    /// is reachable once that changes. This pins today's behavior so the change is noticed.
    @Test("A certificate sign-in is refused by swift-nio-ssh before it reaches the authenticator")
    func certificateSignInIsRefusedUpstream() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let seen = SeenIdentities()
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .publicKey))
        let listener = try await server.bindListener(group: group) { _, session in
            seen.record(session.clientIdentity)
        }
        let port = try #require(listener.localAddress?.port)
        let delegate = OfferKey(username: "alice", key: try Self.userKey(), certificate: try Self.certificate())
        await #expect(throws: (any Error).self) {
            try await Self.connect(port: port, group: group, delegate: delegate, deadline: .seconds(2))
        }
        try await listener.close()
        try await group.shutdownGracefully()
        #expect(seen.values.isEmpty)
    }
}
