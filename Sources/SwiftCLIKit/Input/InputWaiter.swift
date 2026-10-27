// InputWaiter.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-27.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(os)
import os
#endif

/// Whether one ``KeyReader/nextKey()`` call has been cancelled.
///
/// Each call has its own, so a wake meant for an earlier, cancelled call can't end a later one.
final class ReadCancellation: Sendable {
    private let state = LockedState(false)

    /// Marks the call cancelled.
    func cancel() {
        state.withLock { $0 = true }
    }

    /// Whether the call was cancelled.
    var isCancelled: Bool {
        state.withLock { $0 }
    }
}

/// Waits for a descriptor to become readable, off the cooperative thread pool, in a way another
/// thread can interrupt: `poll(2)` over the descriptor and the read end of a wake pipe.
final class InputWaiter: Sendable {
    #if canImport(os)
    private static let logger = Logger(subsystem: "com.swiftclikit", category: "InputWaiter")
    #endif

    /// What a wait ended with.
    enum Outcome: Sendable, Equatable {
        /// The descriptor has a byte, or has reached end of input or an error, which a read reports.
        case readable
        /// The wake pipe was written: someone wants this wait to look at its cancellation.
        case woken
        /// The timeout passed with nothing to read.
        case timedOut
    }

    /// The serial queue every wait runs on: one reader, one queue.
    let queue = DispatchQueue(label: "com.swiftclikit.input")

    /// The wake pipe's read and write ends, or nil if it couldn't be created.
    private let wakePipe: (read: Int32, write: Int32)?

    /// Creates a waiter and its wake pipe.
    init() {
        var ends: [Int32] = [-1, -1]
        if pipe(&ends) == 0 {
            _ = fcntl(ends[0], F_SETFL, fcntl(ends[0], F_GETFL) | O_NONBLOCK)
            _ = fcntl(ends[1], F_SETFL, fcntl(ends[1], F_GETFL) | O_NONBLOCK)
            wakePipe = (ends[0], ends[1])
        } else {
            wakePipe = nil
            #if canImport(os)
            Self.logger.error("no wake pipe (errno \(errno, privacy: .public)): a cancelled key read ends only at the next byte")
            #endif
        }
    }

    deinit {
        if let wakePipe {
            close(wakePipe.read)
            close(wakePipe.write)
        }
    }

    /// Interrupts the wait in progress, or the next one if none is.
    func wake() {
        guard let wakePipe else { return }
        var byte: UInt8 = 1
        // Non-blocking: if the pipe is full, a wake is already pending, which is all this says.
        _ = write(wakePipe.write, &byte, 1)
    }

    /// Waits until `descriptor` is readable, the waiter is woken, or `timeout` passes.
    /// - Parameters:
    ///   - descriptor: The descriptor to read.
    ///   - timeout: How long to wait, or nil to wait for as long as it takes.
    /// - Returns: How the wait ended. A wake is drained before ``Outcome/woken`` is returned.
    func wait(for descriptor: Int32, timeout: Duration?) -> Outcome {
        let milliseconds = timeout.map { Int32(clamping: $0.components.seconds * 1000 + $0.components.attoseconds / 1_000_000_000_000_000) } ?? -1
        var fds = [pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)]
        if let wakePipe {
            fds.append(pollfd(fd: wakePipe.read, events: Int16(POLLIN), revents: 0))
        }
        var ready = poll(&fds, nfds_t(fds.count), milliseconds)
        while ready < 0, errno == EINTR {
            ready = poll(&fds, nfds_t(fds.count), milliseconds)
        }
        // An error polling is left for the read to report, as end of input.
        guard ready >= 0 else { return .readable }
        guard ready > 0 else { return .timedOut }
        if fds[0].revents != 0 { return .readable }
        drainWakes()
        return .woken
    }

    /// Empties the wake pipe, so one wake is seen once.
    private func drainWakes() {
        guard let wakePipe else { return }
        var buffer = [UInt8](repeating: 0, count: 64)
        while read(wakePipe.read, &buffer, buffer.count) > 0 {}
    }
}
