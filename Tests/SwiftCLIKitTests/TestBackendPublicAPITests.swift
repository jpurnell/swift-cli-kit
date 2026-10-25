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
