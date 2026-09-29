// EventStream.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// An asynchronous sequence of terminal ``Event`` values.
///
/// Wraps a ``RawTerminal`` and yields decoded key presses, mouse actions,
/// and resize notifications as they arrive.
///
/// ```swift
/// func handleKey(_ key: Key) {}
///
/// let terminal = RawTerminal()
/// let stream = EventStream(terminal: terminal)
/// for await event in stream {
///     switch event {
///     case .key(let k): handleKey(k)
///     default: break
///     }
/// }
/// ```
public struct EventStream: AsyncSequence, Sendable {
    /// The element type yielded by this sequence.
    public typealias Element = Event

    private let terminal: RawTerminal

    /// Creates an event stream that reads from the given terminal.
    /// - Parameter terminal: The ``RawTerminal`` to read bytes from.
    public init(terminal: RawTerminal) { self.terminal = terminal }

    /// Creates the async iterator for this sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(terminal: terminal)
    }

    /// The iterator that decodes raw bytes into ``Event`` values.
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let reader: KeyReader

        init(terminal: RawTerminal) { self.reader = KeyReader(terminal: terminal) }

        /// Returns the next event, or `nil` on EOF.
        ///
        /// Reads the next key from the underlying ``KeyReader``.
        /// Mouse keys are mapped to ``Event/mouse(_:)``;
        /// all other keys become ``Event/key(_:)``.
        public mutating func next() async -> Event? {
            guard let key = reader.readKey() else { return nil }
            switch key {
            case .mouse(let mouseEvent):
                return .mouse(mouseEvent)
            default:
                return .key(key)
            }
        }
    }
}
