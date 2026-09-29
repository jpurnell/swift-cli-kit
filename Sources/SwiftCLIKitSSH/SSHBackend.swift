// SSHBackend.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation
import SwiftCLIKit
import NIOCore
import NIOSSH
import Synchronization

/// A `TerminalBackend` that operates over an SSH channel.
///
/// Reads input bytes fed by the NIO channel handler and writes output
/// through a provided closure. The SSH channel is inherently in raw mode,
/// so ``enableRawMode()`` and ``disableRawMode()`` are no-ops.
///
/// ```swift
/// import SwiftCLIKit
///
/// // `channel` is whatever carries bytes back to the client — an NIO channel,
/// // a socket, a test double.
/// func makeBackend(write channel: @escaping @Sendable (String) -> Void) throws -> SSHBackend {
///     try SSHBackend(
///         initialSize: TerminalSize(columns: 120, rows: 40),
///         outputHandler: { text in channel(text) }
///     )
/// }
/// let backend = try makeBackend(write: { _ in })
/// backend.feedInput([0x41])  // inject 'A'
/// ```
///
/// - Note: The ``readKey()`` method currently returns `nil` as a placeholder.
///   Full integration requires an async key reader, planned for a future release.
public final class SSHBackend: TerminalBackend, Sendable {
    private let inputBuffer: AsyncStream<UInt8>
    private let inputContinuation: AsyncStream<UInt8>.Continuation
    private let outputHandler: @Sendable (String) -> Void
    private let sizeState: Mutex<TerminalSize>
    /// Whether the SSH session is an interactive PTY. The network analog of
    /// `isatty` — non-interactive `exec` sessions (no PTY) must not receive
    /// cursor/screen-control escapes, which would garble captured output.
    private let isInteractive: Bool

    /// Errors that can occur during SSH backend initialization.
    public enum Error: Swift.Error {
        /// The async stream continuation was unexpectedly unavailable.
        case continuationUnavailable
    }

    /// Creates an SSH backend with the given initial terminal size and output handler.
    /// - Parameters:
    ///   - initialSize: The client's reported terminal dimensions.
    ///   - isInteractive: Whether the session has an interactive PTY. When `false`
    ///     (a non-interactive `exec`), cursor/screen-control escapes are suppressed
    ///     so captured output stays clean — the SSH analog of an `isatty` check.
    ///   - outputHandler: A closure called with strings to send to the SSH client.
    /// - Throws: ``Error/continuationUnavailable`` if the async stream continuation
    ///   cannot be obtained.
    public init(
        initialSize: TerminalSize = TerminalSize(columns: 80, rows: 24),
        isInteractive: Bool = true,
        outputHandler: @escaping @Sendable (String) -> Void
    ) throws {
        self.sizeState = Mutex(initialSize)
        self.isInteractive = isInteractive
        self.outputHandler = outputHandler
        var cont: AsyncStream<UInt8>.Continuation?
        self.inputBuffer = AsyncStream { cont = $0 }
        guard let continuation = cont else {
            throw Error.continuationUnavailable
        }
        self.inputContinuation = continuation
    }

    /// Feeds raw bytes from the SSH channel into the input buffer.
    ///
    /// Called by the SSH channel handler when data arrives from the client.
    /// - Parameter bytes: The raw bytes received from the SSH channel.
    public func feedInput(_ bytes: [UInt8]) {
        for byte in bytes {
            inputContinuation.yield(byte)
        }
    }

    /// Updates the terminal size, typically in response to a window-change request.
    /// - Parameter newSize: The new terminal dimensions.
    public func updateSize(_ newSize: TerminalSize) {
        sizeState.withLock { $0 = newSize }
    }

    // MARK: - TerminalBackend Conformance

    /// No-op: SSH channels are already in raw mode.
    public func enableRawMode() throws { }

    /// No-op: SSH channels do not have a "cooked" mode to restore.
    public func disableRawMode() { }

    /// Reads the next key from the SSH input stream.
    ///
    /// - Note: Currently returns `nil` as a placeholder. Full async key reading
    ///   integration is planned for a future release.
    /// - Returns: The next `Key`, or `nil`.
    public func readKey() -> Key? {
        // Placeholder: full implementation needs async byte reading
        // to bridge NIO's event-driven delivery with the synchronous readKey() API.
        nil
    }

    /// Returns the current terminal dimensions as reported by the SSH client.
    public func terminalSize() -> TerminalSize {
        sizeState.withLock { $0 }
    }

    /// Writes a string to the SSH channel via the output handler.
    /// - Parameter string: The text to send to the client.
    public func write(_ string: String) {
        outputHandler(string)
    }

    /// Sends the alternate screen enter sequence to the SSH client.
    public func enterAlternateScreen() {
        guard isInteractive else { return }   // no PTY: suppress screen control
        write("\u{1B}[?1049h")
    }

    /// Sends the alternate screen leave sequence to the SSH client.
    public func leaveAlternateScreen() {
        guard isInteractive else { return }   // no PTY: suppress screen control
        write("\u{1B}[?1049l")
    }

    /// Sends the mouse tracking enable sequence to the SSH client.
    public func enableMouse() {
        guard isInteractive else { return }   // no PTY: suppress screen control
        write(MouseMode.enable)
    }

    /// Sends the mouse tracking disable sequence to the SSH client.
    public func disableMouse() {
        guard isInteractive else { return }   // no PTY: suppress screen control
        write(MouseMode.disable)
    }

    /// Sends the cursor hide sequence to the SSH client.
    public func hideCursor() {
        guard isInteractive else { return }   // no PTY: suppress screen control
        write(CursorControl.hide)
    }

    /// Sends the cursor show sequence to the SSH client.
    public func showCursor() {
        guard isInteractive else { return }   // no PTY: suppress screen control
        write(CursorControl.show)
    }
}
