// SSHSessionChannelHandler.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-07-14.

import Foundation
import NIOCore
@preconcurrency import NIOSSH
#if canImport(os)
import os
#endif
import SwiftCLIKit

/// A NIO channel handler that turns one SSH session channel into a running
/// SwiftCLIKit app.
///
/// The handler folds the client's channel requests through
/// ``SSHSessionRequestState`` — capturing PTY allocation, terminal size, and
/// whether a `shell` or `exec` was asked for. When the establishing request
/// arrives it builds an ``SSHBackend`` whose ``SSHBackend/isInteractive`` flag
/// reflects the negotiated PTY state, then invokes the server's session handler.
/// Inbound channel data is forwarded to the backend's input stream; the
/// backend's output is written back to the SSH channel.
final class SSHSessionChannelHandler: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData
    typealias OutboundOut = SSHChannelData

    #if canImport(os)
    private static let logger = Logger(subsystem: "com.swiftclikit", category: "SSHSession")
    #endif

    /// Accumulated request state; interactivity is decided here.
    private var state = SSHSessionRequestState()
    /// The backend for this session, created once an establishing request arrives.
    private var backend: SSHBackend?
    /// The server's per-session app entry point.
    private let sessionHandler: @Sendable (SSHBackend, SSHSession) async throws -> Void
    /// The remote client's address, for the ``SSHSession`` record.
    private let remoteAddress: String

    /// Creates a session handler for a single SSH child channel.
    /// - Parameters:
    ///   - remoteAddress: The connecting client's address.
    ///   - sessionHandler: The server's per-connection app entry point.
    init(
        remoteAddress: String,
        sessionHandler: @escaping @Sendable (SSHBackend, SSHSession) async throws -> Void
    ) {
        self.remoteAddress = remoteAddress
        self.sessionHandler = sessionHandler
    }

    /// Folds inbound channel requests into ``state`` and establishes the session
    /// on the first `shell`/`exec` request.
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if state.apply(event), backend == nil {
            establishSession(context: context)
        }
        context.fireUserInboundEventTriggered(event)
    }

    /// Forwards inbound channel bytes to the backend's input stream.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        guard channelData.type == .channel, case .byteBuffer(let buffer) = channelData.data else {
            return
        }
        let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) ?? []
        guard !bytes.isEmpty else { return }
        backend?.feedInput(bytes)
    }

    /// Builds the backend with the negotiated interactivity/size and launches
    /// the session handler on a detached task.
    private func establishSession(context: ChannelHandlerContext) {
        let eventLoop = context.channel.eventLoop
        let boundChannel = NIOLoopBound(context.channel, eventLoop: eventLoop)
        let outputHandler: @Sendable (String) -> Void = { text in
            eventLoop.execute {
                let channel = boundChannel.value
                var buffer = channel.allocator.buffer(capacity: text.utf8.count)
                buffer.writeString(text)
                let data = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
                channel.writeAndFlush(data, promise: nil)
            }
        }

        let newBackend: SSHBackend
        do {
            newBackend = try SSHBackend(
                initialSize: state.terminalSize,
                isInteractive: state.isInteractive,
                outputHandler: outputHandler
            )
        } catch {
            #if canImport(os)
            Self.logger.error("Failed to create SSH backend: \(String(describing: error), privacy: .public)")
            #endif
            context.close(promise: nil)
            return
        }
        backend = newBackend

        let session = SSHSession(
            id: UUID().uuidString,
            remoteAddress: remoteAddress,
            terminalSize: state.terminalSize
        )
        // Closing hops back onto the channel's event loop; kept as a standalone
        // @Sendable closure so the detached task captures only Sendable values.
        let closeChannel: @Sendable () -> Void = {
            eventLoop.execute { boundChannel.value.close(promise: nil) }
        }
        launch(backend: newBackend, session: session, close: closeChannel)
    }

    /// Runs the session handler on a detached task, capturing only `Sendable`
    /// values so region-based isolation stays trivially satisfiable.
    private func launch(
        backend: SSHBackend,
        session: SSHSession,
        close: @escaping @Sendable () -> Void
    ) {
        let handler = sessionHandler
        // Collapse the task's captures to a single @Sendable closure; capturing
        // several values directly trips a region-isolation-checker bug (Swift 6.4).
        let operation: @Sendable () async -> Void = {
            await Self.runSession(handler: handler, backend: backend, session: session, close: close)
        }
        Task { await operation() }
    }

    /// Awaits the session handler and then closes the channel. Kept as a plain
    /// `async` function so the enclosing `Task` closure is a single call the
    /// isolation checker can analyze.
    private static func runSession(
        handler: @Sendable (SSHBackend, SSHSession) async throws -> Void,
        backend: SSHBackend,
        session: SSHSession,
        close: @Sendable () -> Void
    ) async {
        do {
            try await handler(backend, session)
        } catch {
            #if canImport(os)
            logger.error("SSH session handler failed: \(String(describing: error), privacy: .public)")
            #endif
        }
        close()
    }
}
