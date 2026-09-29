// InputHistory.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A bounded, navigable history of input lines (like shell history with arrow keys).
///
/// ```swift
/// var history = InputHistory(maxEntries: 50)
/// history.add("first command")
/// history.add("second command")
/// let prev = history.navigateUp(current: "")   // "second command"
/// let older = history.navigateUp(current: "")   // "first command"
/// let newer = history.navigateDown()             // "second command"
/// ```
public struct InputHistory: Sendable {
    private let maxEntries: Int
    private var entries: [String] = []
    private var navigationIndex: Int = -1
    private var stashedCurrent: String = ""

    /// Creates a history buffer with the given capacity.
    /// - Parameter maxEntries: Maximum entries to retain. Defaults to 100.
    public init(maxEntries: Int = 100) { self.maxEntries = maxEntries }

    /// Appends a non-empty line to the history, deduplicating consecutive entries.
    /// - Parameter line: The input line to record.
    public mutating func add(_ line: String) {
        guard !line.isEmpty else { return }
        if entries.last == line { return }
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst()
        }
    }

    /// Moves backward (older) in history. On the first call, stashes the current input.
    /// - Parameter current: The user's current in-progress text (stashed for later restore).
    /// - Returns: The older history entry, or `nil` if already at the oldest.
    public mutating func navigateUp(current: String) -> String? {
        if navigationIndex == -1 {
            stashedCurrent = current
            navigationIndex = entries.count - 1
        } else {
            navigationIndex -= 1
        }
        guard navigationIndex >= 0 else {
            navigationIndex = 0
            return nil
        }
        return entries[navigationIndex]
    }

    /// Moves forward (newer) in history, eventually restoring the stashed current text.
    /// - Returns: The newer history entry, or the stashed text when past the newest entry.
    public mutating func navigateDown() -> String? {
        guard navigationIndex >= 0 else { return nil }
        navigationIndex += 1
        if navigationIndex >= entries.count {
            navigationIndex = -1
            return stashedCurrent
        }
        return entries[navigationIndex]
    }

    /// Resets the navigation position so the next up-arrow starts from the end again.
    public mutating func reset() {
        navigationIndex = -1
        stashedCurrent = ""
    }
}
