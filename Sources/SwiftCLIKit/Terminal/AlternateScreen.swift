// AlternateScreen.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Manages the terminal alternate screen buffer.
///
/// On creation, switches the terminal to the alternate screen.
/// On deallocation, restores the original screen content.
/// The original screen is automatically restored when the instance is deallocated (RAII pattern).
///
/// ```swift
/// func drawUI() {}
///
/// func runFullscreenUI() {
///     let screen = AlternateScreen()
///     // Terminal is now on the alternate buffer.
///     print(CursorControl.hide)
///     drawUI()
///     // When `screen` goes out of scope, the original content reappears.
/// }
/// ```
public final class AlternateScreen: Sendable {
    private let fd: Int32
    private let _isActive: Mutex<Bool>

    /// Whether the alternate screen is currently active.
    public var isActive: Bool {
        _isActive.withLock { $0 }
    }

    /// Creates an alternate screen on the given file descriptor.
    ///
    /// Switching buffers is a no-op when `fileDescriptor` is not a terminal. The escape
    /// sequence has no meaning to a pipe or a file — it arrives as the literal bytes
    /// `ESC[?1049h` in whatever reads the output, corrupting it — so a redirected run
    /// leaves the descriptor alone and reports ``isActive`` as `false`.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The POSIX file descriptor to write to (default: STDOUT).
    ///   - isTerminal: How terminal-ness is decided. Defaults to `isatty`; a caller that
    ///     has already resolved the question — or a test driving a pipe — can supply it.
    public init(fileDescriptor: Int32 = 1, isTerminal: (Int32) -> Bool = { isatty($0) != 0 }) {
        self.fd = fileDescriptor
        self._isActive = Mutex(false)
        guard isTerminal(fileDescriptor) else { return }
        writeEscape("\u{001B}[?1049h")
        _isActive.withLock { $0 = true }
    }

    deinit {
        // Only restore a screen this instance actually switched: on a non-terminal
        // descriptor there is nothing to leave, and writing the leave sequence would put
        // the very bytes into the stream that init declined to write.
        guard _isActive.withLock({ $0 }) else { return }
        writeEscape("\u{001B}[?1049l")
    }

    private func writeEscape(_ seq: String) {
        let bytes = Array(seq.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return }
            _ = write(fd, ptr, buffer.count)
        }
    }
}
