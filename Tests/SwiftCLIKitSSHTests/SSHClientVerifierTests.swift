// SSHClientVerifierTests.swift
// SwiftCLIKitSSH

import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
import SwiftCLIKit
@testable import SwiftCLIKitSSH

/// Offers one credential, then gives up.
private final class OfferOnce: NIOSSHClientUserAuthenticationDelegate, Sendable {
    let offer: NIOSSHUserAuthenticationOffer
    private let offered = LockedState(false)

    init(username: String, password: String) {
        offer = .init(username: username, serviceName: "", offer: .password(.init(password: password)))
    }

    init(username: String, key: NIOSSHPrivateKey) {
        offer = .init(username: username, serviceName: "", offer: .privateKey(.init(privateKey: key)))
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        let first = offered.withLock { done -> Bool in
            defer { done = true }
            return !done
        }
        nextChallengePromise.succeed(first ? offer : nil)
    }
}

private final class TrustAnyHostKey: NIOSSHClientServerAuthenticationDelegate, Sendable {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

/// What a session handler saw.
private final class Sessions: Sendable {
    private let state: LockedState<[SSHSession]> = LockedState([])

    func record(_ session: SSHSession) {
        state.withLock { $0.append(session) }
    }

    var values: [SSHSession] {
        state.withLock { $0 }
    }
}

/// A verifier that answers from a closure and records what it was shown.
private final class ScriptedVerifier: SSHClientVerifier, Sendable {
    let methods: SSHVerificationMethods
    private let decide: @Sendable (SSHAuthenticationAttempt) async -> SSHVerdict
    private let seen: LockedState<[String]> = LockedState([])

    init(
        methods: SSHVerificationMethods = [.password, .publicKey],
        decide: @escaping @Sendable (SSHAuthenticationAttempt) async -> SSHVerdict
    ) {
        self.methods = methods
        self.decide = decide
    }

    var attempts: [String] {
        seen.withLock { $0 }
    }

    func verify(_ attempt: SSHAuthenticationAttempt) async -> SSHVerdict {
        seen.withLock { $0.append("\(attempt.username):\(attempt.evidence.kind):\(attempt.password ?? "-")") }
        return await decide(attempt)
    }
}

/// What a verifier attaches for the session: here, the subject it resolved.
private struct Resolved: Sendable, Equatable {
    let subjectID: String
}

/// Releases a held verifier once the test says so.
private actor Latch {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var open = false

    func wait() async {
        guard !open else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        open = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

/// An identity layer's checks are asynchronous: SwiftIdentity's `Authenticator` resolves
/// across stores and throttles through a ledger. A synchronous `(String, String) -> Bool`
/// can't call it without blocking a thread, and leaves no way to carry what it resolved into
/// the session. ``SSHConfiguration/AuthMode/verifier(_:)`` is the asynchronous seam.
@Suite("SSH client verifier")
struct SSHClientVerifierTests {

    private static func fixtureKey(_ name: String) throws -> NIOSSHPrivateKey {
        let source = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHClientVerifierTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        return try OpenSSHHostKeyFile(path: destination.path).load()
    }

    private static func fixtureLine(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        let line = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        return line.split(separator: " ").prefix(2).joined(separator: " ")
    }

    /// Signs in and opens a session; returns once the server closes it. Throws if the sign-in
    /// is refused (the session never opens before `deadline`).
    private static func signIn(
        port: Int, group: any EventLoopGroup, delegate: OfferOnce, deadline: TimeAmount = .seconds(10)
    ) async throws {
        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .client(.init(userAuthDelegate: delegate, serverAuthDelegate: TrustAnyHostKey())),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                }
            }
            .connect(host: "127.0.0.1", port: port)
            .get()
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

    /// Runs `body` against a server in `mode`, recording each session.
    private static func withServer(
        _ mode: SSHConfiguration.AuthMode,
        threads: Int = 1,
        _ body: (Int, any EventLoopGroup) async throws -> Void
    ) async throws -> [SSHSession] {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: threads)
        let sessions = Sessions()
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: mode))
        let listener = try await server.bindListener(group: group) { _, session in
            sessions.record(session)
        }
        let port = try #require(listener.localAddress?.port)
        do {
            try await body(port, group)
        } catch {
            try await listener.close()
            try await group.shutdownGracefully()
            throw error
        }
        try await listener.close()
        try await group.shutdownGracefully()
        return sessions.values
    }

    // MARK: - The mode

    @Test("A verifier mode authenticates clients, and offers only the methods it names")
    func methods() {
        let both = SSHConfiguration.AuthMode.verifier(ScriptedVerifier { _ in .refuse })
        #expect(both.authenticatesClients)
        #expect(SSHAuthenticator(mode: both).supportedAuthenticationMethods == [.password, .publicKey])
        let keysOnly = SSHConfiguration.AuthMode.verifier(ScriptedVerifier(methods: .publicKey) { _ in .refuse })
        #expect(SSHAuthenticator(mode: keysOnly).supportedAuthenticationMethods == .publicKey)
    }

    @Test("An attempt's description never shows the password")
    func attemptIsRedacted() {
        let attempt = SSHAuthenticationAttempt(username: "ada", evidence: .password, password: "correct horse")
        #expect(!String(describing: attempt).contains("correct horse"))
        #expect(!String(reflecting: attempt).contains("correct horse"))
        var dumped = ""
        dump(attempt, to: &dumped)
        #expect(!dumped.contains("correct horse"))
    }

    // MARK: - Over the wire

    @Test("A verifier sees the password, and what it attaches reaches the session")
    func passwordAdmittedWithAttachment() async throws {
        let verifier = ScriptedVerifier { attempt in
            attempt.password == "correct horse" ? .admit(attaching: Resolved(subjectID: "subject-1")) : .refuse
        }
        let sessions = try await Self.withServer(.verifier(verifier)) { port, group in
            try await Self.signIn(port: port, group: group, delegate: OfferOnce(username: "ada", password: "correct horse"))
        }
        #expect(verifier.attempts == ["ada:password:correct horse"])
        let session = try #require(sessions.first)
        #expect(session.clientIdentity == SSHClientIdentity(username: "ada", evidence: .password))
        #expect(session.verification as? Resolved == Resolved(subjectID: "subject-1"))
    }

    @Test("A refusal opens no session")
    func refusalOpensNothing() async throws {
        let verifier = ScriptedVerifier { _ in .refuse }
        let sessions = try await Self.withServer(.verifier(verifier)) { port, group in
            await #expect(throws: (any Error).self) {
                try await Self.signIn(
                    port: port, group: group, delegate: OfferOnce(username: "ada", password: "wrong"), deadline: .seconds(2)
                )
            }
        }
        #expect(sessions.isEmpty)
        #expect(verifier.attempts == ["ada:password:wrong"])
    }

    @Test("A verifier sees a key's OpenSSH form, and an admit with nothing attached leaves verification nil")
    func keyAdmitted() async throws {
        let key = try Self.fixtureKey("user_ed25519")
        let expected = try Self.fixtureLine("user_ed25519.pub")
        let verifier = ScriptedVerifier { attempt in
            attempt.evidence.openSSHPublicKey == expected ? .admit : .refuse
        }
        let sessions = try await Self.withServer(.verifier(verifier)) { port, group in
            try await Self.signIn(port: port, group: group, delegate: OfferOnce(username: "ada", key: key))
        }
        #expect(verifier.attempts == ["ada:public-key:-"])
        let session = try #require(sessions.first)
        #expect(session.clientIdentity?.evidence.openSSHPublicKey == expected)
        #expect(session.verification == nil)
    }

    @Test("A method the verifier didn't name is refused without asking it")
    func unnamedMethodRefused() async throws {
        let verifier = ScriptedVerifier(methods: .publicKey) { _ in .admit }
        let sessions = try await Self.withServer(.verifier(verifier)) { port, group in
            await #expect(throws: (any Error).self) {
                try await Self.signIn(
                    port: port, group: group, delegate: OfferOnce(username: "ada", password: "anything"), deadline: .seconds(2)
                )
            }
        }
        #expect(sessions.isEmpty)
        #expect(verifier.attempts.isEmpty)
    }

    @Test("A verifier still working doesn't hold up another connection on the same event loop")
    func suspendedVerifierDoesNotBlock() async throws {
        let latch = Latch()
        let verifier = ScriptedVerifier { attempt in
            if attempt.username == "slow" { await latch.wait() }
            return .admit
        }
        let sessions = try await Self.withServer(.verifier(verifier)) { port, group in
            async let slow: Void = Self.signIn(port: port, group: group, delegate: OfferOnce(username: "slow", password: "p"))
            while !verifier.attempts.contains("slow:password:p") {
                try await Task.sleep(for: .milliseconds(5))
            }
            try await Self.signIn(
                port: port, group: group, delegate: OfferOnce(username: "fast", password: "p"), deadline: .seconds(3)
            )
            await latch.release()
            try await slow
        }
        // `slow` is released only after `fast` has been admitted and served.
        #expect(sessions.map { $0.clientIdentity?.username } == ["fast", "slow"])
    }

    @Test("The attempt cap counts a verifier's refusals")
    func capApplies() throws {
        let verifier = ScriptedVerifier { _ in .refuse }
        let closed = LockedState(0)
        let authenticator = SSHAuthenticator(mode: .verifier(verifier), maxAttempts: 2, disconnect: { closed.withLock { $0 += 1 } })
        for password in ["one", "two", "three"] {
            let promise = MultiThreadedEventLoopGroup.singleton.next().makePromise(of: NIOSSHUserAuthenticationOutcome.self)
            authenticator.requestReceived(
                request: .init(username: "ada", serviceName: "ssh-connection", request: .password(.init(password: password))),
                responsePromise: promise
            )
            _ = try promise.futureResult.wait()
        }
        #expect(verifier.attempts == ["ada:password:one", "ada:password:two"])
        #expect(closed.withLock { $0 } >= 1)
    }
}
