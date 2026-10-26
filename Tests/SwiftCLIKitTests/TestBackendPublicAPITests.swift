// TestBackendPublicAPITests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-25.

import Testing
import SwiftCLIKit

/// Drives `TestBackend` through its public API only, as a consumer's tests would. Nothing in the
/// library records renders into a `TestBackend`, so a consumer must be able to.
@Suite("TestBackend public API")
struct TestBackendPublicAPITests {

    @Test("a consumer records a rendered frame and reads it back")
    func consumerRecordsRender() {
        let backend = TestBackend(width: 4, height: 1)
        var frame = Frame(buffer: CellBuffer(width: 4, height: 1), rect: Rect(x: 0, y: 0, width: 4, height: 1))
        frame.writeText("ok", x: 0, y: 0)

        backend.submitRender(frame.cellBuffer)

        #expect(backend.renderHistory.count == 1)
        #expect(backend.currentBuffer == frame.cellBuffer)
    }
}

@Suite("TestBackend key input")
struct TestBackendKeyInputTests {

    @Test("Injected keys are what nextKey() returns, in order; other events are skipped")
    func injectedKeys() async {
        let backend = TestBackend(width: 10, height: 2)
        await backend.inject(.key(.character("a")))
        await backend.inject(.resize(width: 20, height: 4))
        await backend.injectSequence([.key(.enter), .key(.ctrlC)])
        #expect(await backend.nextKey() == .character("a"))
        #expect(await backend.nextKey() == .enter)
        #expect(await backend.nextKey() == .ctrlC)
    }

    @Test("isAwaitingKey says when code under test is reading")
    func awaitingKey() async {
        let backend = TestBackend(width: 10, height: 2)
        #expect(!backend.isAwaitingKey)
        let reading = Task { await backend.nextKey() }
        for _ in 0..<100_000 where !backend.isAwaitingKey { await Task.yield() }
        #expect(backend.isAwaitingKey)
        await backend.inject(.key(.enter))
        #expect(await reading.value == .enter)
        #expect(!backend.isAwaitingKey)
    }

    @Test("Ending input releases a reader with nil")
    func endInput() async {
        let backend = TestBackend(width: 10, height: 2)
        await backend.inject(.key(.tab))
        backend.endInput()
        #expect(await backend.nextKey() == .tab)
        #expect(await backend.nextKey() == nil)
    }
}
