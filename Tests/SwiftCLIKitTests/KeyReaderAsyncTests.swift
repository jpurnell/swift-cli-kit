// KeyReaderAsyncTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-27.

import Testing
import Foundation
import SwiftCLIKit

/// `KeyReader.nextKey()`: a local terminal's read that a task can cancel, and a lone Escape
/// that arrives without waiting for the next key.
///
/// Imports SwiftCLIKit without `@testable`: all of this is public.
@Suite("KeyReader.nextKey")
struct KeyReaderAsyncTests {

    /// A reader over a pipe, and the pipe's writing end.
    private struct Wire {
        let pipe = Pipe()
        let reader: KeyReader

        init() {
            reader = KeyReader(terminal: RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor))
        }

        func send(_ bytes: [UInt8]) {
            pipe.fileHandleForWriting.write(Data(bytes))
        }

        func end() {
            pipe.fileHandleForWriting.closeFile()
        }

        /// Waits until the reader has taken every byte written so far, so a test knows a key has
        /// begun rather than guessing from a delay.
        func untilDrained() async throws {
            for _ in 0..<400 {
                // A zero-timeout poll reports unread bytes without taking any.
                var unread = pollfd(fd: pipe.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
                guard poll(&unread, 1, 0) > 0 else { return }
                try await Task.sleep(for: .milliseconds(5))
            }
        }
    }

    @Test("A key already written is returned, and so is one written while waiting")
    func returnsKeys() async throws {
        let wire = Wire()
        wire.send([0x61])
        #expect(await wire.reader.nextKey() == .character("a"))

        async let next = wire.reader.nextKey()
        try await Task.sleep(for: .milliseconds(50))
        wire.send([0x62])
        #expect(await next == .character("b"))
    }

    @Test("A sequence written at once is one key")
    func sequence() async {
        let wire = Wire()
        wire.send([0x1B, 0x5B, 0x41])
        #expect(await wire.reader.nextKey() == .arrowUp)
    }

    @Test("A lone Escape is .escape after the timeout, not held until the next key")
    func loneEscape() async {
        let wire = Wire()
        wire.send([0x1B])
        let started = ContinuousClock.now

        let key = await wire.reader.nextKey()

        #expect(key == .escape)
        #expect(ContinuousClock.now - started < .seconds(2))
        #expect(KeyReader.escapeTimeout == .milliseconds(50))
    }

    @Test("Cancelling a waiting read returns nil promptly, and a later key isn't lost")
    func cancel() async throws {
        let wire = Wire()
        let waiting = Task { await wire.reader.nextKey() }
        try await Task.sleep(for: .milliseconds(50))
        let started = ContinuousClock.now

        waiting.cancel()
        let cancelled = await waiting.value

        #expect(cancelled == nil)
        #expect(ContinuousClock.now - started < .seconds(2))
        wire.send([0x63])
        #expect(await wire.reader.nextKey() == .character("c"))
    }

    @Test("A cancellation after a key has begun still returns the whole key")
    func cancelMidKey() async throws {
        let wire = Wire()
        wire.send([0x1B, 0x5B])
        let reading = Task { await wire.reader.nextKey() }
        // A fixed delay here failed under the load of a clean build: the read hadn't started,
        // so the cancellation came between keys and ended the wait, as designed.
        try await wire.untilDrained()

        reading.cancel()
        try await Task.sleep(for: .milliseconds(20))
        wire.send([0x42])

        #expect(await reading.value == .arrowDown)
    }

    @Test("A wake meant for a cancelled read doesn't end the next one")
    func staleWake() async throws {
        let wire = Wire()
        let first = Task { await wire.reader.nextKey() }
        try await Task.sleep(for: .milliseconds(20))
        first.cancel()
        _ = await first.value

        async let second = wire.reader.nextKey()
        try await Task.sleep(for: .milliseconds(100))
        wire.send([0x64])
        #expect(await second == .character("d"))
    }

    @Test("End of input is nil")
    func endOfInput() async {
        let wire = Wire()
        wire.end()
        #expect(await wire.reader.nextKey() == nil)
    }
}
