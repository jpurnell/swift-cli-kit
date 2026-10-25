// SessionReplayTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
import Testing
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

/// A message whose encoding always fails, to drive the recorder's failure path.
private struct UnencodableMsg: Codable, Sendable {
    struct Refused: Error {}
    init() {}
    init(from decoder: any Decoder) throws { throw Refused() }
    func encode(to encoder: any Encoder) throws { throw Refused() }
}

// MARK: - SessionRecorder Tests

/// A path that resolved outside the per-test sandbox directory.
private struct SandboxEscape: Error, CustomStringConvertible {
    let path: String
    var description: String { "path escapes the test sandbox: \(path)" }
}

@Suite final class SessionRecorderTests {

    /// Every file these tests create lives under this root; nothing else is touched.
    private static let sandboxRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).standardized

    private let tempDir: URL

    init() throws {
        tempDir = Self.sandboxRoot
            .appendingPathComponent("SwiftCLIKitTests_\(UUID().uuidString)", isDirectory: true)
            .standardized
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    deinit {
        // Only ever remove a directory strictly inside the sandbox root.
        let dir = tempDir.standardized
        if dir != Self.sandboxRoot, dir.pathComponents.starts(with: Self.sandboxRoot.pathComponents) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    /// Resolves `name` inside the sandbox, refusing anything that traverses out of it.
    private func tempURL(_ name: String) throws -> URL {
        let resolved = tempDir.appendingPathComponent(name).standardized
        guard resolved.pathComponents.starts(with: tempDir.pathComponents) else { throw SandboxEscape(path: resolved.path) }
        return resolved
    }

    private func tempPath(_ name: String) throws -> String {
        try tempURL(name).path
    }

    /// Record 3 entries and verify the file has 3 lines.
    @Test func recordThreeEntriesProducesThreeLines() throws {
        let path = try tempPath("three_entries.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)

        recorder.record(key: "a", timestamp: 0.0)
        recorder.record(key: "b", timestamp: 0.5)
        recorder.record(message: .increment, timestamp: 1.0)
        try recorder.close()

        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.lines.filter { !$0.isEmpty }
        #expect(lines.count == 3)
    }

    /// Record and close produces valid JSON-lines (each line is valid JSON).
    @Test func recordAndCloseProducesValidJSONLines() throws {
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
            #expect(entry.timestamp >= 0.0)
        }
    }

    /// Replay produces the correct number of model snapshots.
    @Test func replayProducesCorrectModelCount() throws {
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
        try #require(snapshots.count == 3)
        #expect(snapshots[0].count == 1)
        #expect(snapshots[1].count == 2)
        #expect(snapshots[2].count == 1)
    }

    /// Empty file produces empty snapshots array.
    @Test func emptyFileProducesEmptySnapshots() throws {
        let url = try tempURL("empty.jsonl")
        try Data().write(to: url)

        let player = SessionPlayer<TestModel, TestMsg>(
            inputPath: url.path,
            initialModel: TestModel(),
            update: testUpdate
        )
        let snapshots = try player.play()

        #expect(snapshots.isEmpty)
    }

    /// Corrupted line is skipped; valid lines still produce snapshots.
    @Test func corruptedFileSkipsInvalidLines() throws {
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
        try #require(snapshots.count == 2)
        #expect(snapshots[0].count == 1)  // increment
        #expect(snapshots[1].count == 10) // set(10)
    }
    /// The replay reports which records it skipped, so a malformed line is visible, not just absent.
    @Test func replayReportsSkippedRecords() throws {
        let path = try tempPath("skipped.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)
        recorder.record(message: .increment, timestamp: 0.0)
        try recorder.close()

        let handle = try #require(FileHandle(forWritingAtPath: path))
        handle.seekToEndOfFile()
        handle.write(Data("NOT VALID JSON\n".utf8))
        handle.write(Data("{\"also\": \"wrong\"}\n".utf8))
        handle.closeFile()

        let player = SessionPlayer<TestModel, TestMsg>(
            inputPath: path,
            initialModel: TestModel(),
            update: testUpdate
        )
        let result = try player.replay()

        #expect(result.snapshots.map(\.count) == [1])
        #expect(result.skippedRecords == [2, 3])
    }

    /// A clean recording skips nothing.
    @Test func replayOfCleanFileSkipsNothing() throws {
        let path = try tempPath("clean.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)
        recorder.record(message: .increment, timestamp: 0.0)
        recorder.record(key: "a", timestamp: 0.1)
        try recorder.close()

        let player = SessionPlayer<TestModel, TestMsg>(
            inputPath: path,
            initialModel: TestModel(),
            update: testUpdate
        )
        let result = try player.replay()

        #expect(result.snapshots.count == 1)
        #expect(result.skippedRecords.isEmpty)
    }

    /// An entry that cannot be encoded is reported as not written, and nothing reaches the file.
    @Test func unencodableEntryIsReportedAndNotWritten() throws {
        let path = try tempPath("unencodable.jsonl")
        let recorder = SessionRecorder<UnencodableMsg>(outputPath: path)

        let written = recorder.writeLine(SessionEntry(timestamp: 0.0, kind: .message(UnencodableMsg())))
        try recorder.close()

        #expect(written == false)
        let contents = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(contents.isEmpty)
    }

    /// An encodable entry is reported as written.
    @Test func encodableEntryIsReportedWritten() throws {
        let path = try tempPath("encodable.jsonl")
        let recorder = SessionRecorder<TestMsg>(outputPath: path)

        let written = recorder.writeLine(SessionEntry(timestamp: 0.0, kind: .message(.increment)))
        try recorder.close()

        #expect(written)
        let contents = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        #expect(contents.hasSuffix("\n"))
    }
}
