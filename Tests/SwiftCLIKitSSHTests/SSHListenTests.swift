// SSHListenTests.swift
// SwiftCLIKitSSH

import Testing
import Foundation
import NIOCore
import NIOPosix
import SwiftCLIKit
import SwiftCLIKitSSH

/// Collects what a raw TCP client reads, and fulfils a promise with the first line.
private final class FirstLine: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    private let line: EventLoopPromise<String>

    init(_ line: EventLoopPromise<String>) {
        self.line = line
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        let text = buffer.readString(length: buffer.readableBytes) ?? ""
        line.succeed(String(text.prefix { $0 != "\r" && $0 != "\n" }))
    }
}

/// `SSHServer.listen`: a running server a caller can address and stop, without NIO in the API.
///
/// Imports SwiftCLIKitSSH without `@testable`, so everything here is public.
@Suite("SSHServer.listen")
struct SSHListenTests {

    /// Connects over plain TCP and returns the first line the server sends: its SSH banner.
    private static func banner(port: Int, group: any EventLoopGroup) async throws -> String {
        let line = group.next().makePromise(of: String.self)
        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(FirstLine(line))
                }
            }
            .connect(host: SSHServer.loopbackHost, port: port)
            .get()
        let timer = group.next().scheduleTask(in: .seconds(10)) {
            line.fail(ChannelError.connectTimeout(.seconds(10)))
        }
        defer { timer.cancel() }
        let text = try await line.futureResult.get()
        try await client.close()
        return text
    }

    @Test("Listening on port 0 reports the port the system chose, and an SSH server answers there")
    func reportsPort() async throws {
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .publicKey))
        let listener = try await server.listen { _, _ in }
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let line = try await Self.banner(port: listener.port, group: group)

        try await listener.close()
        try await group.shutdownGracefully()
        #expect(listener.port > 0)
        #expect(line.hasPrefix("SSH-2.0-"))
    }

    @Test("close() ends waitUntilClosed(), the port stops accepting, and closing again is no error")
    func closes() async throws {
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .publicKey))
        let listener = try await server.listen { _, _ in }
        let port = listener.port

        async let waited: Void = listener.waitUntilClosed()
        try await listener.close()
        try await waited
        try await listener.close()

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        await #expect(throws: (any Error).self) {
            try await ClientBootstrap(group: group).connect(host: SSHServer.loopbackHost, port: port).get()
        }
        try await group.shutdownGracefully()
    }

    @Test("A host key file that can't be used throws from listen, before anything listens")
    func refusesBadHostKey() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)").path
        let server = SSHServer(
            port: 0, hostKeySource: .filePath(path), configuration: SSHConfiguration(authMode: .publicKey)
        )
        await #expect(throws: SSHServer.HostKeyError.unreadable(path: path)) {
            _ = try await server.listen { _, _ in }
        }
    }
}
