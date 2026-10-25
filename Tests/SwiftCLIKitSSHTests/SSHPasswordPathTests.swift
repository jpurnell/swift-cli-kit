// SSHPasswordPathTests.swift
// SwiftCLIKitSSH

import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
import SwiftCLIKit
@testable import SwiftCLIKitSSH

/// Offers one password, then gives up.
private final class OfferPassword: NIOSSHClientUserAuthenticationDelegate, Sendable {
    let username: String
    let password: String
    private let offered = LockedState(false)

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        let first = offered.withLock { done -> Bool in
            defer { done = true }
            return !done
        }
        guard first, availableMethods.contains(.password) else {
            nextChallengePromise.succeed(nil)
            return
        }
        nextChallengePromise.succeed(
            .init(username: username, serviceName: "", offer: .password(.init(password: password)))
        )
    }
}

private final class AcceptAnyHostKey: NIOSSHClientServerAuthenticationDelegate, Sendable {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

/// The order things happened in, as the test and the validator saw them.
private final class Events: Sendable {
    private let state: LockedState<[String]> = LockedState([])

    func append(_ event: String) {
        state.withLock { $0.append(event) }
    }

    var values: [String] {
        state.withLock { $0 }
    }
}

/// The password validator used to run on the connection's event loop, so a strong KDF — the
/// 600,000-round PBKDF2 or Argon2id that SwiftIdentity 0.7.0 uses — stalled every other connection
/// on that loop while it worked.
@Suite("SSH password path")
struct SSHPasswordPathTests {

    /// Signs in with a password and opens a session; returns once the server closes it.
    private static func signIn(
        port: Int, group: any EventLoopGroup, username: String, password: String,
        deadline: TimeAmount = .seconds(10)
    ) async throws {
        let delegate = OfferPassword(username: username, password: password)
        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .client(.init(userAuthDelegate: delegate, serverAuthDelegate: AcceptAnyHostKey())),
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

    @Test("A validator still working doesn't hold up another connection on the same event loop")
    func validatorRunsOffTheEventLoop() async throws {
        // One event loop serves both connections, so if the validator ran on it, `fast` could
        // not be admitted while `slow` is held. Checked by order, not by timing: `slow` is
        // released only after `fast` has been admitted.
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let release = DispatchSemaphore(value: 0)
        let events = Events()
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .password { user, _ in
            if user == "slow" {
                events.append("slow validating")
                _ = release.wait(timeout: .now() + 10)
            }
            return true
        }))
        let listener = try await server.bindListener(group: group) { _, session in
            events.append("\(session.clientIdentity?.username ?? "?") admitted")
        }
        let port = try #require(listener.localAddress?.port)

        async let slow: Void = Self.signIn(port: port, group: group, username: "slow", password: "p")
        // Wait (without the event loop) until the slow validator holds its thread.
        while !events.values.contains("slow validating") {
            try await Task.sleep(for: .milliseconds(5))
        }
        try await Self.signIn(port: port, group: group, username: "fast", password: "p", deadline: .seconds(3))
        events.append("released")
        release.signal()
        try await slow
        try await listener.close()
        try await group.shutdownGracefully()

        #expect(events.values == ["slow validating", "fast admitted", "released", "slow admitted"])
    }
}

/// Offers a wrong password every time it's asked, up to `limit` times.
private final class KeepGuessing: NIOSSHClientUserAuthenticationDelegate, Sendable {
    let limit: Int
    private let offers = LockedState(0)

    init(limit: Int) {
        self.limit = limit
    }

    var offered: Int {
        offers.withLock { $0 }
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        let next = offers.withLock { count -> Int? in
            guard count < limit else { return nil }
            count += 1
            return count
        }
        guard let next else {
            nextChallengePromise.succeed(nil)
            return
        }
        nextChallengePromise.succeed(
            .init(username: "ada", serviceName: "", offer: .password(.init(password: "guess \(next)")))
        )
    }
}

/// Counts the validator's calls.
private final class Calls: Sendable {
    private let state = LockedState(0)

    func record() {
        state.withLock { $0 += 1 }
    }

    var count: Int {
        state.withLock { $0 }
    }
}

/// NIST SP 800-63B-4 asks for a limit on consecutive failed attempts. Per subject, that's the
/// identity layer's ledger; per connection, it's the server's: nothing stopped one connection
/// guessing for as long as it liked.
@Suite("SSH attempt cap")
struct SSHAttemptCapTests {

    private static func request(_ password: String) -> NIOSSHUserAuthenticationRequest {
        NIOSSHUserAuthenticationRequest(
            username: "ada", serviceName: "ssh-connection", request: .password(.init(password: password))
        )
    }

    private static func answer(_ authenticator: SSHAuthenticator, _ password: String) throws -> Bool {
        let promise = MultiThreadedEventLoopGroup.singleton.next().makePromise(of: NIOSSHUserAuthenticationOutcome.self)
        authenticator.requestReceived(request: request(password), responsePromise: promise)
        if case .success = try promise.futureResult.wait() { return true }
        return false
    }

    @Test("The default cap is OpenSSH's MaxAuthTries default, 6")
    func defaultCap() {
        #expect(SSHConfiguration(authMode: .publicKey).maxAuthAttempts == 6)
        #expect(SSHConfiguration(maxAuthAttempts: 3, authMode: .publicKey).maxAuthAttempts == 3)
    }

    @Test("After the cap's failures the connection is closed, and the next attempt isn't validated")
    func capDisconnects() throws {
        let calls = Calls()
        let disconnects = Calls()
        let authenticator = SSHAuthenticator(
            mode: .password { _, _ in calls.record(); return false },
            maxAttempts: 3,
            disconnect: { disconnects.record() }
        )
        #expect(try !Self.answer(authenticator, "one"))
        #expect(try !Self.answer(authenticator, "two"))
        #expect(disconnects.count == 0)
        #expect(try !Self.answer(authenticator, "three"))
        #expect(disconnects.count == 1)
        #expect(try !Self.answer(authenticator, "four"))
        #expect(calls.count == 3)
    }

    @Test("A success within the cap admits")
    func successWithinCap() throws {
        let authenticator = SSHAuthenticator(
            mode: .password { _, password in password == "right" }, maxAttempts: 3, disconnect: {}
        )
        #expect(try !Self.answer(authenticator, "wrong"))
        #expect(try !Self.answer(authenticator, "wrong"))
        #expect(try Self.answer(authenticator, "right"))
        #expect(authenticator.admitted?.username == "ada")
    }

    @Test("The probe every client sends first doesn't count against the cap")
    func noneDoesNotCount() throws {
        let disconnects = Calls()
        let authenticator = SSHAuthenticator(
            mode: .password { _, password in password == "right" }, maxAttempts: 1, disconnect: { disconnects.record() }
        )
        let probe = MultiThreadedEventLoopGroup.singleton.next().makePromise(of: NIOSSHUserAuthenticationOutcome.self)
        authenticator.requestReceived(
            request: .init(username: "ada", serviceName: "ssh-connection", request: .none), responsePromise: probe
        )
        _ = try probe.futureResult.wait()
        #expect(disconnects.count == 0)
        #expect(try Self.answer(authenticator, "right"))
    }

    @Test("Over the wire, a client that keeps guessing is disconnected at the cap")
    func overTheWire() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let calls = Calls()
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .password { _, _ in
            calls.record()
            return false
        }))
        let listener = try await server.bindListener(group: group) { _, _ in }
        let port = try #require(listener.localAddress?.port)
        let guesser = KeepGuessing(limit: 20)
        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .client(.init(userAuthDelegate: guesser, serverAuthDelegate: AcceptAnyHostKey())),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                }
            }
            .connect(host: "127.0.0.1", port: port)
            .get()
        let timer = client.eventLoop.scheduleTask(in: .seconds(10)) { client.close(promise: nil) }
        try await client.closeFuture.get()
        timer.cancel()
        try await listener.close()
        try await group.shutdownGracefully()

        #expect(calls.count == 6)
        #expect(guesser.offered < 20, "closed by the server, not by the client giving up")
    }
}
