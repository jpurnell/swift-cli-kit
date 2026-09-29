// TextReflow.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-07-03.

import Foundation

/// Rejoins hard-wrapped terminal lines into logical, copy-ready text.
///
/// Full-screen TUIs word-wrap paragraphs into fixed-width grid rows, so copying
/// a rendered region yields a newline at every wrap point. ``TextReflow``
/// reverses that: consecutive non-blank lines are joined back into a single
/// logical line, while blank lines are preserved as paragraph breaks.
///
/// ```swift
/// let logical = TextReflow.unwrap(["The quick brown", "fox jumps"])
/// // "The quick brown fox jumps"
/// ```
///
/// - Note: This is a heuristic suited to prose. It cannot recover structure
///   (list bullets, tables) that relied purely on visual line breaks.
public enum TextReflow: Sendable {

    /// Rejoins visually wrapped lines into logical paragraphs.
    ///
    /// Trailing whitespace is trimmed from each line. Runs of non-blank lines
    /// are joined with a single space; one or more blank lines separate
    /// paragraphs, and leading/trailing blank lines are ignored.
    /// - Parameter lines: The wrapped visual lines, in order.
    /// - Returns: The reflowed text, with paragraphs separated by a blank line.
    public static func unwrap(_ lines: [String]) -> String {
        var paragraphs: [String] = []
        var current: [String] = []

        func flush() {
            guard !current.isEmpty else { return }
            paragraphs.append(current.joined(separator: " "))
            current.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let trimmed = trimTrailing(line)
            if trimmed.isEmpty {
                flush()
            } else {
                current.append(trimmed)
            }
        }
        flush()

        return paragraphs.joined(separator: "\n\n")
    }

    /// Strips ANSI escape sequences from each line, then reflows them.
    /// - Parameter lines: The rendered visual lines, possibly containing escapes.
    /// - Returns: The reflowed plain text.
    public static func unwrap(rendered lines: [String]) -> String {
        unwrap(lines.map(ANSIStringMetrics.plainText))
    }

    /// Removes trailing whitespace from a single line.
    private static func trimTrailing(_ line: String) -> String {
        var end = line.endIndex
        while end > line.startIndex {
            let previous = line.index(before: end)
            guard line[previous].isWhitespace else { break }
            end = previous
        }
        return String(line[line.startIndex..<end])
    }
}
