// Key.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A decoded terminal key press, produced by ``KeyReader``.
public enum Key: Sendable, Equatable {
    // MARK: - Printable
    /// A printable Unicode character (including multi-byte UTF-8).
    case character(Character)

    // MARK: - Editing
    /// Backspace (0x7F).
    case backspace
    /// Forward-delete (CSI 3~).
    case delete
    /// Enter / Return (0x0A or 0x0D).
    case enter
    /// Tab (0x09).
    case tab
    /// Bare Escape (0x1B with no following CSI).
    case escape

    // MARK: - Navigation
    /// Arrow keys (CSI A/B/C/D).
    case arrowUp, arrowDown, arrowLeft, arrowRight
    /// Home (CSI H) and End (CSI F).
    case home, end

    // MARK: - Control keys
    /// Common Ctrl combinations used in line editing and signal handling.
    case ctrlC, ctrlD, ctrlA, ctrlE, ctrlK, ctrlW, ctrlU, ctrlL

    // MARK: - v0.2.0 additions
    /// A mouse event decoded from SGR protocol bytes.
    case mouse(MouseEvent)
    /// A function key (F1-F12).
    case functionKey(Int)
    /// Page Up (CSI 5~).
    case pageUp
    /// Page Down (CSI 6~).
    case pageDown
    /// Insert (CSI 2~).
    case insert
    /// Shift-Tab / Backtab (CSI Z).
    case backtab

    // MARK: - Fallback
    /// An unrecognised byte value.
    case unknown(UInt8)
}
