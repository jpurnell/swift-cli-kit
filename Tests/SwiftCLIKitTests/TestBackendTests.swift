// TestBackendTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("TestBackend")
struct TestBackendTests {

    @Test("dimensions match init parameters")
    func dimensions() {
        let backend = TestBackend(width: 80, height: 24)
        #expect(backend.width == 80)
        #expect(backend.height == 24)
    }

    @Test("inject yields event in event stream")
    func createAndInject() async throws {
        let backend = TestBackend(width: 80, height: 24)
        await backend.inject(.key(.character("a")))

        // Use withThrowingTaskGroup + sleep-based timeout to avoid hanging
        let received: Event? = try await withThrowingTaskGroup(of: Event?.self) { group in
            group.addTask {
                for await event in backend.eventStream {
                    return event
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: .milliseconds(500))
                return nil
            }
            // Whichever finishes first wins
            let result = try await group.next() ?? nil
            group.cancelAll()
            return result
        }

        if case .key(let key) = received {
            #expect(key == .character("a"))
        } else {
            // Expected failure: inject is a no-op stub, so no event received
            #expect(Bool(false), "inject() should yield a .key(.character(\"a\")) event into the stream")
        }
    }

    @Test("submitRender updates currentBuffer")
    func submitRender() {
        let backend = TestBackend(width: 10, height: 5)
        var buf = CellBuffer(width: 10, height: 5)
        buf[0, 0] = Cell(character: "X")
        backend.submitRender(buf)
        #expect(backend.currentBuffer[0, 0].character == "X")
    }

    @Test("renderHistory accumulates submitted buffers")
    func renderHistory() {
        let backend = TestBackend(width: 10, height: 5)
        let buf = CellBuffer(width: 10, height: 5)
        backend.submitRender(buf)
        backend.submitRender(buf)
        backend.submitRender(buf)
        #expect(backend.renderHistory.count == 3)
    }

    @Test("clearHistory empties render history")
    func clearHistory() {
        let backend = TestBackend(width: 10, height: 5)
        let buf = CellBuffer(width: 10, height: 5)
        backend.submitRender(buf)
        backend.clearHistory()
        #expect(backend.renderHistory.isEmpty)
    }
}
