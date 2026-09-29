// SessionReplayTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import XCTest
@testable import SwiftCLIKit

// MARK: - Test Message Type

private enum TestMsg: Codable, Sendable, Equatable {
    case increment
    case decrement
    case set(Int)
}

private struct TestModel: Sendable, Equatable {
    var count: Int = 0
}

private func testUpdate(model: inout TestModel, message: TestMsg) -> [Cmd<TestMsg>] {
    switch message {
    case .increment:
        model.count += 1
    case .decrement:
        model.count -= 1
    case .set(let value):
        model.count = value
    }
    return [.none]
}

// MARK: - SessionRecorder Tests

/// A path that resolved outside the per-test sandbox directory.
private struct SandboxEscape: Error, CustomStringConvertible {
    let path: String
    var description: String { "path escapes the test sandbox: \(path)" }
}

final class SessionRecorderTests: XCTestCase {

    /// Every file these tests create lives under this root; nothing else is touched.
    private static let sandboxRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).standardized

    private var tempDir = SessionRecorderTests.sandboxRoot

    override func setUp() {
        super.setUp()
        tempDir = Self.sandboxRoot
            .appendingPathComponent("SwiftCLIKitTests_\(UUID().uuidString)", isDirectory: true)
            .standardized
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Only ever remove a directory strictly inside the sandbox root.
        let dir = tempDir.standardized
        if dir != Self.sandboxRoot, dir.path.hasPrefix(Self.sandboxRoot.path) {
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }

    /// Resolves `name` inside the sandbox, refusing anything that traverses out of it.
    private func tempURL(_ name: String) throws -> URL {
        let resolved = tempDir.appendingPathComponent(name).standardized
        guard resolved.path.hasPrefix(tempDir.path) else { throw SandboxEscape(path: resolved.path) }
        return resolved
    }

    private func tempPath(_ name: String) throws -> String {
        try tempURL(name).path
    }

    /// Record 3 entries and verify the file has 3 lines.
    func testRecordThreeEntriesProducesThreeLines() throws {
        let path = try tempPath("three_entries.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)

        recorder.record(key: "a", timestamp: 0.0)
        recorder.record(key: "b", timestamp: 0.5)
        recorder.record(message: .increment, timestamp: 1.0)
        try recorder.close()

        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.lines.filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3)
    }

    /// Record and close produces valid JSON-lines (each line is valid JSON).
    func testRecordAndCloseProducesValidJSONLines() throws {
        let path = try tempPath("valid_json.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)

        recorder.record(key: "enter", timestamp: 0.0)
        recorder.record(message: .increment, timestamp: 0.5)
        recorder.record(message: .set(42), timestamp: 1.0)
        try recorder.close()

        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.lines.filter { !$0.isEmpty }
        let decoder = JSONDecoder()

        for line in lines {
            let data = Data(line.utf8)
            let entry = try decoder.decode(SessionEntry<TestMsg>.self, from: data)
            XCTAssertGreaterThanOrEqual(entry.timestamp, 0.0)
        }
    }

    /// Replay produces the correct number of model snapshots.
    func testReplayProducesCorrectModelCount() throws {
        let path = try tempPath("replay_count.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)

        recorder.record(message: .increment, timestamp: 0.0)
        recorder.record(message: .increment, timestamp: 0.5)
        recorder.record(message: .decrement, timestamp: 1.0)
        recorder.record(key: "x", timestamp: 1.5) // key event, no snapshot
        try recorder.close()

        let player = SessionPlayer<TestModel, TestMsg>(
            inputPath: path,
            initialModel: TestModel(),
            update: testUpdate
        )
        let snapshots = try player.play()

        // 3 message entries produce 3 snapshots; key event is skipped
        XCTAssertEqual(snapshots.count, 3)
        XCTAssertEqual(snapshots[0].count, 1)
        XCTAssertEqual(snapshots[1].count, 2)
        XCTAssertEqual(snapshots[2].count, 1)
    }

    /// Empty file produces empty snapshots array.
    func testEmptyFileProducesEmptySnapshots() throws {
        let url = try tempURL("empty.jsonl")
        try Data().write(to: url)

        let player = SessionPlayer<TestModel, TestMsg>(
            inputPath: url.path,
            initialModel: TestModel(),
            update: testUpdate
        )
        let snapshots = try player.play()

        XCTAssertTrue(snapshots.isEmpty)
    }

    /// Corrupted line is skipped; valid lines still produce snapshots.
    func testCorruptedFileSkipsInvalidLines() throws {
        let path = try tempPath("corrupted.jsonl")

        // Write a valid entry, then garbage, then another valid entry
        let recorder = SessionRecorder<TestMsg>(outputPath: path)
        recorder.record(message: .increment, timestamp: 0.0)
        try recorder.close()

        // Append corrupted line and another valid line
        let handle = FileHandle(forWritingAtPath: path)
        handle?.seekToEndOfFile()
        handle?.write(Data("NOT VALID JSON\n".utf8))

        // Write another valid entry manually
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let entry = SessionEntry<TestMsg>(timestamp: 1.0, kind: .message(.set(10)))
        if let data = try? encoder.encode(entry) {
            var line = data
            line.append(contentsOf: [UInt8(ascii: "\n")])
            handle?.write(line)
        }
        handle?.closeFile()

        let player = SessionPlayer<TestModel, TestMsg>(
            inputPath: path,
            initialModel: TestModel(),
            update: testUpdate
        )
        let snapshots = try player.play()

        // 2 valid message entries, corrupted line skipped
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].count, 1)  // increment
        XCTAssertEqual(snapshots[1].count, 10) // set(10)
    }
}
