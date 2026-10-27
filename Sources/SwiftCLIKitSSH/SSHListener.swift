// SSHListener.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-10-26.

import NIOCore
import NIOPosix

/// A running ``SSHServer``, from ``SSHServer/listen(sessionHandler:)``.
///
/// It owns the server's event loops and shuts them down when the server closes, whether by
/// ``close()`` or because the listening socket closed on its own.
public actor SSHListener {
    /// The port the server bound: the one it was given, or the system's choice when that was 0.
    public nonisolated let port: Int

    private let channel: any Channel
    private let group: MultiThreadedEventLoopGroup
    private var shutDown = false

    init(channel: any Channel, group: MultiThreadedEventLoopGroup, requestedPort: Int) {
        self.channel = channel
        self.group = group
        // A bound TCP socket always has a local address; the requested port is the same number
        // unless it was 0.
        self.port = channel.localAddress?.port ?? requestedPort
    }

    /// Stops accepting connections, closes the server and shuts down its event loops. Calling it
    /// again, or after the server closed on its own, does nothing.
    /// - Throws: Any error shutting down the event loops.
    public func close() async throws {
        guard !shutDown else { return }
        channel.close(promise: nil)
        try await waitUntilClosed()
    }

    /// Returns once the server has closed, then shuts down its event loops.
    /// - Throws: Any error the listening socket closed with, or from shutting down.
    public func waitUntilClosed() async throws {
        // Once the event loops are gone, a future's callbacks never run: waiting on one would
        // never return.
        guard !shutDown else { return }
        do {
            try await channel.closeFuture.get()
        } catch {
            try await shutDownOnce()
            throw error
        }
        try await shutDownOnce()
    }

    /// Shuts the event loops down, the first time only.
    private func shutDownOnce() async throws {
        guard !shutDown else { return }
        shutDown = true
        try await group.shutdownGracefully()
    }
}
