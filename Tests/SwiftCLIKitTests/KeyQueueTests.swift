// KeyQueueTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-25.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("KeyQueue")
struct KeyQueueTests {

    @Test("A key pushed before anyone waits is delivered to the next reader")
    func bufferedKey() async {
        let queue = KeyQueue(capacity: 8)
        #expect(queue.push(.character("a")))
        #expect(await queue.next() == .character("a"))
    }

    @Test("A reader that waits is woken by the next push")
    func waitingReader() async {
        let queue = KeyQueue(capacity: 8)
        let reader = Task { await queue.next() }
        await Self.waitUntil { queue.waiterCount == 1 }
        #expect(queue.push(.enter))
        #expect(await reader.value == .enter)
    }

    @Test("Waiting readers are served in the order they started waiting")
    func fifoReaders() async {
        let queue = KeyQueue(capacity: 8)
        let first = Task { await queue.next() }
        await Self.waitUntil { queue.waiterCount == 1 }
        let second = Task { await queue.next() }
        await Self.waitUntil { queue.waiterCount == 2 }
        _ = queue.push(.character("1"))
        _ = queue.push(.character("2"))
        #expect(await first.value == .character("1"))
        #expect(await second.value == .character("2"))
    }

    @Test("Ending input delivers what's buffered, then nil, and wakes waiters with nil")
    func endOfInput() async {
        let buffered = KeyQueue(capacity: 8)
        _ = buffered.push(.tab)
        buffered.end()
        #expect(await buffered.next() == .tab)
        #expect(await buffered.next() == nil)
        #expect(!buffered.push(.enter))

        let waiting = KeyQueue(capacity: 8)
        let reader = Task { await waiting.next() }
        await Self.waitUntil { waiting.waiterCount == 1 }
        waiting.end()
        #expect(await reader.value == nil)
    }

    @Test("A cancelled reader gets nil, and the next key is kept for someone else")
    func cancelledReader() async {
        let queue = KeyQueue(capacity: 8)
        let reader = Task { await queue.next() }
        await Self.waitUntil { queue.waiterCount == 1 }
        reader.cancel()
        #expect(await reader.value == nil)
        #expect(queue.waiterCount == 0)
        _ = queue.push(.character("k"))
        #expect(queue.tryNext() == .character("k"))
    }

    @Test("A reader already cancelled when it asks gets nil without waiting")
    func cancelledBeforeAsking() async {
        let queue = KeyQueue(capacity: 8)
        let reader = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await queue.next()
        }
        #expect(await reader.value == nil)
        #expect(queue.waiterCount == 0)
    }

    @Test("Keys past capacity are dropped, not queued")
    func capacity() {
        let queue = KeyQueue(capacity: 2)
        #expect(queue.push(.character("a")))
        #expect(queue.push(.character("b")))
        #expect(!queue.push(.character("c")))
        #expect(queue.tryNext() == .character("a"))
        #expect(queue.tryNext() == .character("b"))
        #expect(queue.tryNext() == nil)
    }

    @Test("A backend that implements only readKey() answers nextKey() from it")
    func defaultNextKey() async {
        let backend = ScriptedBackend(keys: [.character("x"), .enter])
        #expect(await backend.nextKey() == .character("x"))
        #expect(await backend.nextKey() == .enter)
        #expect(await backend.nextKey() == nil)
    }

    /// Yields until `condition` holds, so a test can wait for a reader to register without
    /// sleeping for a guessed duration.
    static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100_000 where !condition() {
            await Task.yield()
        }
    }
}

/// A backend with nothing but `readKey()`, answered from a script.
private final class ScriptedBackend: TerminalBackend, Sendable {
    private let keys: LockedState<[Key]>
    init(keys: [Key]) { self.keys = LockedState(keys) }
    func enableRawMode() throws {}
    func disableRawMode() {}
    func readKey() -> Key? { keys.withLock { $0.isEmpty ? nil : $0.removeFirst() } }
    func terminalSize() -> TerminalSize { TerminalSize(columns: 80, rows: 24) }
    func write(_ string: String) {}
    func enterAlternateScreen() {}
    func leaveAlternateScreen() {}
    func enableMouse() {}
    func disableMouse() {}
    func hideCursor() {}
    func showCursor() {}
}
