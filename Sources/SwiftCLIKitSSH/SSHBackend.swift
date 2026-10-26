// SSHBackend.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Foundation
import SwiftCLIKit
import NIOCore
import NIOSSH

/// A `TerminalBackend` that operates over an SSH channel.
///
/// Decodes the bytes the channel handler feeds it into keys, which ``nextKey()`` delivers, and
/// writes output through a provided closure. The SSH channel is inherently in raw mode, so
/// ``enableRawMode()`` and ``disableRawMode()`` are no-ops.
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
/// let key = backend.readKey()  // .character("A")
/// ```
///
/// A session reads keys with `await backend.nextKey()`, which returns `nil` once the client
/// closes the channel. Keys arrive decoded as ``KeyReader`` decodes a terminal's, through
/// ``KeyDecoder``; up to ``maxQueuedKeys`` are held while the session isn't reading, and more are
/// dropped.
public final class SSHBackend: TerminalBackend, Sendable {
    /// The most keys held for a session that isn't reading. Past it, keys are dropped, so a
    /// client can't grow a session's memory by typing into it.
    public static let maxQueuedKeys = 4096

    /// The decoder for the channel's bytes, which may split a key across reads.
    private let decoder: LockedState<KeyDecoder>
    /// Decoded keys, until the session reads them.
    let keys = KeyQueue(capacity: SSHBackend.maxQueuedKeys)
    private let outputHandler: @Sendable (String) -> Void
    private let sizeState: LockedState<TerminalSize>
    /// Whether the SSH session is an interactive PTY. The network analog of
    /// `isatty` — non-interactive `exec` sessions (no PTY) must not receive
    /// cursor/screen-control escapes, which would garble captured output.
    private let isInteractive: Bool

    /// Errors that can occur during SSH backend initialization.
    public enum Error: Swift.Error {
        /// The async stream continuation was unexpectedly unavailable. Not thrown since 2.3.0,
        /// when input stopped going through an `AsyncStream`; kept so existing `catch`
        /// clauses compile.
        case continuationUnavailable
    }

    /// Creates an SSH backend with the given initial terminal size and output handler.
    /// - Parameters:
    ///   - initialSize: The client's reported terminal dimensions.
    ///   - isInteractive: Whether the session has an interactive PTY. When `false`
    ///     (a non-interactive `exec`), cursor/screen-control escapes are suppressed
    ///     so captured output stays clean — the SSH analog of an `isatty` check.
    ///   - maxPasteBytes: The largest bracketed paste, in UTF-8 bytes, to deliver as
    ///     ``Key/paste(_:)``; a longer one is refused whole. Defaults to
    ///     ``KeyReader/defaultMaxPasteBytes``.
    ///   - outputHandler: A closure called with strings to send to the SSH client.
    /// - Throws: Nothing since 2.3.0; the signature is kept so existing `try` compiles.
    public init(
        initialSize: TerminalSize = TerminalSize(columns: 80, rows: 24),
        isInteractive: Bool = true,
        maxPasteBytes: Int = KeyReader.defaultMaxPasteBytes,
        outputHandler: @escaping @Sendable (String) -> Void
    ) throws {
        self.sizeState = LockedState(initialSize)
        self.isInteractive = isInteractive
        self.outputHandler = outputHandler
        self.decoder = LockedState(KeyDecoder(maxPasteBytes: maxPasteBytes))
    }

    /// Decodes bytes from the SSH channel into keys for ``nextKey()``.
    ///
    /// Called by the SSH channel handler when data arrives from the client. A key may be split
    /// across calls. A bracketed paste that runs past four times its cap with no end marker
    /// ends the input, as it ends a ``KeyReader``'s.
    /// - Parameter bytes: The raw bytes received from the SSH channel.
    public func feedInput(_ bytes: [UInt8]) {
        let (decoded, finished) = decoder.withLock { decoder -> ([Key], Bool) in
            var decoded: [Key] = []
            for byte in bytes {
                if let key = decoder.feed(byte) { decoded.append(key) }
                if decoder.isFinished { break }
            }
            return (decoded, decoder.isFinished)
        }
        for key in decoded {
            keys.push(key)
        }
        if finished {
            keys.end()
        }
    }

    /// Ends the input: a key left incomplete is resolved as at end of input, keys already
    /// decoded are still delivered, and then ``nextKey()`` returns `nil`.
    ///
    /// Called by the SSH channel handler when the channel closes, so a session waiting for a
    /// key is released rather than left waiting.
    public func finishInput() {
        let pending = decoder.withLock { $0.finish() }
        if let pending {
            keys.push(pending)
        }
        keys.end()
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

    /// A key the client has typed, without waiting: an SSH channel can't block for input.
    /// Sessions read with ``nextKey()``.
    /// - Returns: The oldest key not yet read, or `nil` if none has arrived.
    public func readKey() -> Key? {
        keys.tryNext()
    }

    /// The next key the client typed, waiting for one if none has arrived.
    /// - Returns: The key, or `nil` once the channel has closed and every key has been read, or
    ///   when the calling task is cancelled.
    public func nextKey() async -> Key? {
        await keys.next()
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
