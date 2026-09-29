// TerminalBackend.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Protocol abstracting terminal I/O so apps can run on different backends
/// (real terminal, test backend, SSH channel, WASM/xterm.js).
public protocol TerminalBackend: Sendable {
    /// Enter raw mode (disable echo, line buffering).
    func enableRawMode() throws
    /// Restore original terminal mode.
    func disableRawMode()
    /// Read the next key from input. Blocks until available. Returns nil on EOF.
    func readKey() -> Key?
    /// Query the current terminal dimensions.
    func terminalSize() -> TerminalSize
    /// Write a string to the terminal output.
    func write(_ string: String)
    /// Enter the alternate screen buffer.
    func enterAlternateScreen()
    /// Leave the alternate screen buffer.
    func leaveAlternateScreen()
    /// Enable mouse tracking.
    func enableMouse()
    /// Disable mouse tracking.
    func disableMouse()
    /// Hide the cursor.
    func hideCursor()
    /// Show the cursor.
    func showCursor()
}
