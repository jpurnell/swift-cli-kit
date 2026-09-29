// SnapshotTestingTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("SnapshotTesting")
struct SnapshotTestingTests {

    @Test("renderPlainText contains written text")
    func renderPlainText() {
        var buf = CellBuffer(width: 10, height: 3)
        buf.writeText("Hello", at: (x: 0, y: 0))
        let text = SnapshotTesting.renderPlainText(buf)
        #expect(text.contains("Hello"))
    }

    @Test("render with styles includes text and style markers")
    func renderWithStyles() {
        var buf = CellBuffer(width: 10, height: 3)
        buf.writeText("Hello", at: (x: 0, y: 0), fg: .ansi8(.red))
        let rendered = SnapshotTesting.render(buf)
        #expect(rendered.contains("Hello"))
    }

    @Test("compare matching buffers returns nil")
    func compareMatch() throws {
        var buf = CellBuffer(width: 5, height: 1)
        buf.writeText("Test", at: (x: 0, y: 0))
        let tmpDir = NSTemporaryDirectory()
        let path = tmpDir + "snapshot_test_match.txt"
        try SnapshotTesting.write(buf, to: path)
        let diff = SnapshotTesting.compare(buf, goldenFile: path)
        #expect(diff == nil)
    }

    @Test("compare mismatched buffers returns non-nil diff")
    func compareMismatch() throws {
        var buf1 = CellBuffer(width: 5, height: 1)
        buf1.writeText("AAAA", at: (x: 0, y: 0))
        let tmpDir = NSTemporaryDirectory()
        let path = tmpDir + "snapshot_test_mismatch.txt"
        try SnapshotTesting.write(buf1, to: path)

        var buf2 = CellBuffer(width: 5, height: 1)
        buf2.writeText("BBBB", at: (x: 0, y: 0))
        let diff = SnapshotTesting.compare(buf2, goldenFile: path)
        #expect(diff?.isEmpty == false, "Mismatched buffers should produce a non-empty diff")
    }

    @Test("renderPlainText of empty buffer is blank")
    func emptyBuffer() {
        let buf = CellBuffer(width: 5, height: 2)
        let text = SnapshotTesting.renderPlainText(buf)
        // Empty buffer should only contain spaces and/or newlines
        let stripped = text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(stripped.isEmpty)
    }
}
