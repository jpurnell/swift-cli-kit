// SessionPlayer.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Replays a recorded session file through an update function,
/// producing model snapshots at each message step.
///
/// The player reads a JSON-lines file produced by ``SessionRecorder``
/// and feeds each message entry through the provided update function.
/// Key and resize events are skipped during replay (they are informational only).
/// Commands returned by update are discarded to prevent duplicate side effects.
///
/// ```swift
/// struct CounterModel: Sendable { var count = 0 }
/// enum MyMessage: Sendable, Codable { case increment }
///
/// let counterUpdate: @Sendable (inout CounterModel, MyMessage) -> [Cmd<MyMessage>] = {
///     model, _ in
///     model.count += 1
///     return []
/// }
///
/// let player = SessionPlayer(
///     inputPath: "/tmp/session.jsonl",
///     initialModel: CounterModel(count: 0),
///     update: counterUpdate
/// )
/// let snapshots = try player.play()
/// ```
public struct SessionPlayer<Model: Sendable, Message: Codable & Sendable>: Sendable {
    private let inputPath: String
    private let initialModel: Model
    private let update: @Sendable (inout Model, Message) -> [Cmd<Message>]

    /// Creates a new session player.
    /// - Parameters:
    ///   - inputPath: Path to the JSON-lines session file.
    ///   - initialModel: The starting model state for replay.
    ///   - update: The MVU update function to replay messages through.
    public init(
        inputPath: String,
        initialModel: Model,
        update: @Sendable @escaping (inout Model, Message) -> [Cmd<Message>]
    ) {
        self.inputPath = inputPath
        self.initialModel = initialModel
        self.update = update
    }

    /// Replays the entire session and returns model snapshots after each message.
    ///
    /// Only ``SessionEntry/EntryKind/message(_:)`` entries produce snapshots.
    /// Key and resize events are skipped. An empty file returns an empty array.
    /// Lines that cannot be decoded are skipped.
    ///
    /// - Returns: An array of model states, one per message entry.
    /// - Throws: ``SessionPlayerError/fileNotFound(_:)`` if the file does not exist,
    ///   or ``SessionPlayerError/readError(_:)`` if the file cannot be read.
    public func play() throws -> [Model] {
        let data = try readFileData()
        let lines = splitLines(data)

        guard !lines.isEmpty else { return [] }

        let decoder = JSONDecoder()
        var model = initialModel
        var snapshots: [Model] = []

        for line in lines {
            guard !line.isEmpty else { continue }
            guard let entry = try? decoder.decode(SessionEntry<Message>.self, from: line) else { // silent: skip malformed lines during replay
                continue
            }
            switch entry.kind {
            case .message(let msg):
                _ = update(&model, msg)
                snapshots.append(model)
            case .keyEvent, .resizeEvent:
                // Informational only during replay
                break
            }
        }

        return snapshots
    }

    // MARK: - Private

    private func readFileData() throws -> Data {
        let url = URL(fileURLWithPath: inputPath).standardizedFileURL
        // SECURITY: path sanitized via URL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SessionPlayerError.fileNotFound(inputPath)
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SessionPlayerError.readError(error)
        }
    }

    private func splitLines(_ data: Data) -> [Data] {
        let newline = UInt8(ascii: "\n")
        var lines: [Data] = []
        var start = data.startIndex
        for i in data.indices {
            if data[i] == newline {
                if i > start {
                    lines.append(data[start..<i])
                }
                start = data.index(after: i)
            }
        }
        if start < data.endIndex {
            lines.append(data[start..<data.endIndex])
        }
        return lines
    }
}

/// Errors that can occur during session replay.
public enum SessionPlayerError: Error, Sendable {
    /// The session file was not found at the given path.
    case fileNotFound(String)
    /// The session file could not be read.
    case readError(any Error)
}
