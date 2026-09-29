// MouseCapture.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-07-03.

import Foundation

/// Tracks whether terminal mouse reporting is active and vends the escape
/// sequences to toggle it.
///
/// Enabling mouse reporting (DEC private mode 1000) routes button presses to
/// the application, which suppresses the terminal's own click-drag text
/// selection — users must then hold Shift to select. A ``MouseCapture`` lets an
/// event loop temporarily *pause* capture so native selection works without
/// modifiers, then *resume* it, while keeping the on/off state in one place.
///
/// ```swift
/// var mouse = MouseCapture()
/// print(mouse.activate(), terminator: "")   // mouse reporting on
/// // user presses the "copy mode" key:
/// print(mouse.toggle(), terminator: "")      // paused — native selection works
/// print(mouse.toggle(), terminator: "")      // resumed
/// ```
public struct MouseCapture: Sendable, Equatable {
    /// Whether mouse reporting is currently active.
    public private(set) var isActive: Bool

    /// Creates a capture tracker.
    /// - Parameter active: The starting state (default: inactive).
    public init(active: Bool = false) {
        self.isActive = active
    }

    /// Marks capture active and returns the sequence to enable mouse reporting.
    /// - Returns: The ``MouseMode/enable`` escape sequence.
    public mutating func activate() -> String {
        isActive = true
        return MouseMode.enable
    }

    /// Marks capture inactive and returns the sequence to disable mouse
    /// reporting, restoring native text selection.
    /// - Returns: The ``MouseMode/disable`` escape sequence.
    public mutating func pause() -> String {
        isActive = false
        return MouseMode.disable
    }

    /// Flips the current state and returns the sequence to emit.
    /// - Returns: The enable sequence when activating, or the disable sequence when pausing.
    public mutating func toggle() -> String {
        isActive ? pause() : activate()
    }
}
