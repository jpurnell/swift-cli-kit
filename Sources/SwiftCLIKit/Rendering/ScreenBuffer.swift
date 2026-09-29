// ScreenBuffer.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A string-based buffer for composing a single terminal frame before flushing to output.
public struct ScreenBuffer: Sendable {
    /// The intended display width in columns.
    public let width: Int
    private var content: String = ""

    /// Creates a new screen buffer targeting the given column width.
    /// - Parameter width: The display width in columns.
    public init(width: Int) { self.width = width }

    /// Appends text to the buffer without a trailing newline.
    /// - Parameter text: The text to append.
    public mutating func append(_ text: String) { content += text }

    /// Appends text to the buffer followed by a newline.
    /// - Parameter text: The text to append.
    public mutating func appendLine(_ text: String) { content += text + "\n" }

    /// The buffered content prefixed with clear-screen and home-cursor sequences, ready to write as a full frame.
    public var frame: String { ANSICodes.clearScreen + ANSICodes.home + content }

    /// The raw buffered content without any screen-control prefix.
    public var raw: String { content }
}
