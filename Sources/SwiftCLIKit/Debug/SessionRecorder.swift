// SessionRecorder.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
#if canImport(os)
import os

/// Logger for recording. File-scoped because a generic type cannot hold a static stored property.
private let sessionRecorderLogger = Logger(subsystem: "com.swiftclikit", category: "SessionRecorder")
#endif

/// Records session entries to a file in JSON-lines format for later replay.
///
/// Each call to ``record(key:timestamp:)`` or ``record(message:timestamp:)``
/// appends one JSON line to the output file. Call ``close()`` when done to
/// flush and close the file handle.
///
/// ```swift
/// enum MyMessage: Sendable, Codable { case increment }
///
/// let recorder = SessionRecorder<MyMessage>(outputPath: "/tmp/session.jsonl")
/// recorder.record(key: "a", timestamp: 0.0)
/// recorder.record(message: .increment, timestamp: 0.5)
/// try recorder.close()
/// ```
public final class SessionRecorder<Message: Codable & Sendable>: Sendable {
    private let fileHandle: FileHandle
    private let encoder: JSONEncoder
    private let outputPath: String

    /// Creates a new session recorder that writes to the given file path.
    ///
    /// If the file does not exist, it is created. If it exists, it is truncated.
    /// - Parameter outputPath: The file system path for the recording output.
    public init(outputPath: String) {
        let safePath = URL(fileURLWithPath: outputPath).standardizedFileURL.path
        self.outputPath = safePath
        let manager = FileManager.default
        // SECURITY: debug tooling; the developer chooses where the recording goes, and writing it is the point
        if !manager.fileExists(atPath: safePath) {
            // SECURITY: debug tooling; the developer chooses where the recording goes, and writing it is the point
            manager.createFile(atPath: safePath, contents: nil)
        } else {
            if let handle = FileHandle(forWritingAtPath: safePath) {
                handle.truncateFile(atOffset: 0)
                handle.closeFile()
            }
        }
        self.fileHandle = FileHandle(forWritingAtPath: safePath) ?? FileHandle.nullDevice
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    /// Records a key event at the given timestamp.
    /// - Parameters:
    ///   - description: Human-readable key description.
    ///   - timestamp: Seconds since session start.
    public func record(key description: String, timestamp: Double) {
        let entry = SessionEntry<Message>(
            timestamp: timestamp,
            kind: .keyEvent(KeyEventSnapshot(description: description))
        )
        writeLine(entry)
    }

    /// Records a resize event at the given timestamp.
    /// - Parameters:
    ///   - width: New terminal width in columns.
    ///   - height: New terminal height in rows.
    ///   - timestamp: Seconds since session start.
    public func record(resize width: Int, height: Int, timestamp: Double) {
        let entry = SessionEntry<Message>(
            timestamp: timestamp,
            kind: .resizeEvent(width: width, height: height)
        )
        writeLine(entry)
    }

    /// Records an application message at the given timestamp.
    /// - Parameters:
    ///   - message: The application message to record.
    ///   - timestamp: Seconds since session start.
    public func record(message: Message, timestamp: Double) {
        let entry = SessionEntry<Message>(
            timestamp: timestamp,
            kind: .message(message)
        )
        writeLine(entry)
    }

    /// Flushes and closes the recording file.
    /// - Throws: An error if the file cannot be synchronized.
    public func close() throws {
        try fileHandle.synchronize()
        fileHandle.closeFile()
    }

    // MARK: - Private

    /// Appends one entry as a JSON line.
    ///
    /// Recording is best-effort: an entry that cannot be encoded is skipped so the
    /// session carries on, and the failure is logged rather than discarded.
    ///
    /// - Parameter entry: The entry to append.
    /// - Returns: `true` when the entry was written, `false` when it could not be encoded.
    @discardableResult
    func writeLine(_ entry: SessionEntry<Message>) -> Bool {
        let data: Data
        do {
            data = try encoder.encode(entry)
        } catch {
            #if canImport(os)
            sessionRecorderLogger.warning("Skipping unencodable session entry at \(entry.timestamp, privacy: .public)s: \(error.localizedDescription, privacy: .private)")
            #endif
            return false
        }
        var line = data
        line.append(contentsOf: [UInt8(ascii: "\n")])
        fileHandle.write(line)
        return true
    }
}
