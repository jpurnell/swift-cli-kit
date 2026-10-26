// SSHKeyInputTests.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-10-25.

import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
@testable import SwiftCLIKit
@testable import SwiftCLIKitSSH

/// Until 2.3.0, `SSHBackend.readKey()` always returned nil and nothing read the bytes a client
/// sent, so an SSH session could not read a key.
@Suite("SSH key input")
struct SSHKeyInputTests {

    private static func backend() throws -> SSHBackend {
        try SSHBackend(outputHandler: { _ in })
    }

    @Test("A key split across channel reads arrives whole")
    func splitAcrossReads() async throws {
        let backend = try Self.backend()
        backend.feedInput([0x1B])
        backend.feedInput([0x5B])
        backend.feedInput([0x41, 0x61])
        #expect(await backend.nextKey() == .arrowUp)
        #expect(await backend.nextKey() == .character("a"))
    }

    @Test("A session waiting for a key is woken when one arrives")
    func waitingSession() async throws {
        let backend = try Self.backend()
        let reader = Task { await backend.nextKey() }
        await Self.waitUntil { backend.keys.waiterCount == 1 }
        backend.feedInput(Array("é".utf8))
        #expect(await reader.value == .character("é"))
    }

    @Test("readKey() returns a key that has arrived, and nil without waiting when none has")
    func readKeyDoesNotBlock() throws {
        let backend = try Self.backend()
        #expect(backend.readKey() == nil)
        backend.feedInput([0x0D])
        #expect(backend.readKey() == .enter)
        #expect(backend.readKey() == nil)
    }

    @Test("Ending input resolves a dangling escape, then ends")
    func finishInput() async throws {
        let backend = try Self.backend()
        backend.feedInput([0x61, 0x1B])
        backend.finishInput()
        #expect(await backend.nextKey() == .character("a"))
        #expect(await backend.nextKey() == .escape)
        #expect(await backend.nextKey() == nil)
        backend.feedInput([0x62])
        #expect(backend.readKey() == nil)
    }

    @Test("A paste that never ends ends the input")
    func unterminatedPasteEndsInput() async throws {
        let backend = try SSHBackend(maxPasteBytes: 4, outputHandler: { _ in })
        backend.feedInput([0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E] + [UInt8](repeating: 0x61, count: 40))
        #expect(await backend.nextKey() == nil)
    }

    @Test("Keys a session doesn't read are held up to a bound, not without limit")
    func boundedQueue() throws {
        let backend = try Self.backend()
        backend.feedInput([UInt8](repeating: 0x61, count: SSHBackend.maxQueuedKeys + 500))
        #expect(backend.keys.tryNext() == .character("a"))
        var held = 1
        while backend.keys.tryNext() != nil { held += 1 }
        #expect(held == SSHBackend.maxQueuedKeys)
    }

    /// Yields until `condition` holds, so a test can wait for a reader to register without
    /// sleeping for a guessed duration.
    private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100_000 where !condition() {
            await Task.yield()
        }
    }

    // MARK: - Over the wire

    @Test("A client's keystrokes reach the session, and closing the channel ends its input")
    func overTheWire() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let read = group.next().makePromise(of: [Key].self)
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .none))
        let listener = try await server.bindListener(group: group) { backend, _ in
            var keys: [Key] = []
            while let key = await backend.nextKey() { keys.append(key) }
            read.succeed(keys)
        }
        let port = try #require(listener.localAddress?.port)
        // A session that never sees its input end would hang here; this makes it a failure.
        let timer = group.next().scheduleTask(in: .seconds(10)) {
            read.fail(ChannelError.connectTimeout(.seconds(10)))
        }

        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .client(.init(userAuthDelegate: OfferNone(), serverAuthDelegate: TrustAnyHost())),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                }
            }
            .connect(host: "127.0.0.1", port: port)
            .get()
        let opened = client.eventLoop.makePromise(of: Channel.self)
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
        for chunk: [UInt8] in [Array("hi".utf8), [0x1B, 0x5B], [0x41]] {
            var buffer = session.allocator.buffer(capacity: chunk.count)
            buffer.writeBytes(chunk)
            try await session.writeAndFlush(SSHChannelData(type: .channel, data: .byteBuffer(buffer))).get()
        }
        try await session.close()

        let keys = try await read.futureResult.get()
        timer.cancel()
        try await client.close()
        try await listener.close()
        try await group.shutdownGracefully()
        #expect(keys == [.character("h"), .character("i"), .arrowUp])
    }
}

/// Offers the `none` method, which `AuthMode.none` admits.
private final class OfferNone: NIOSSHClientUserAuthenticationDelegate, Sendable {
    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        nextChallengePromise.succeed(.init(username: "ada", serviceName: "", offer: .none))
    }
}

/// Accepts any host key: this test is about input, not the server's identity.
private final class TrustAnyHost: NIOSSHClientServerAuthenticationDelegate, Sendable {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}
