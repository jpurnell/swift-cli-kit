// RawTerminal.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Puts a file descriptor into raw (unbuffered, no-echo) terminal mode and restores
/// the original settings on deallocation.
///
/// Works with real terminals and pipes alike -- if the descriptor is not a TTY,
/// raw mode is skipped but `readByte()` still functions.
///
/// ```swift
/// // Pipe-based usage (e.g. for testing):
/// let pipe = Pipe()
/// pipe.fileHandleForWriting.write(Data([0x41]))  // 'A'
/// pipe.fileHandleForWriting.closeFile()
/// let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
/// let byte = terminal.readByte()  // Optional(65)
/// ```
#if canImport(Darwin) || canImport(Glibc)
private struct RawTerminalState: Sendable {
    var originalTermios: termios?
    var rawModeActive: Bool = false
}
#endif

/// A low-level terminal handle that enables raw (non-canonical) mode on a file descriptor.
///
/// Use `RawTerminal` to disable line buffering and echo so your application receives
/// each keystroke immediately. The original terminal settings are restored on deinitialization.
public final class RawTerminal: Sendable {
    private let fd: Int32
    private let ownsDescriptor: Bool
    #if canImport(Darwin) || canImport(Glibc)
    private let state: Mutex<RawTerminalState>
    #endif

    /// Creates a raw terminal wrapping the given file descriptor.
    ///
    /// The descriptor is duplicated so the caller may close the original freely.
    /// On a real TTY, raw mode is activated immediately and reversed in `deinit`.
    /// - Parameter fileDescriptor: The POSIX file descriptor to read from (default: STDIN).
    public init(fileDescriptor: Int32 = 0) {  // STDIN_FILENO = 0
        let dupFd = dup(fileDescriptor)
        if dupFd >= 0 {
            self.fd = dupFd
            self.ownsDescriptor = true
        } else {
            self.fd = fileDescriptor
            self.ownsDescriptor = false
        }
        #if canImport(Darwin) || canImport(Glibc)
        var initial = RawTerminalState()
        var original = termios()
        if tcgetattr(fd, &original) == 0 {
            initial.originalTermios = original
            var raw = original
            cfmakeraw(&raw)
            if tcsetattr(fd, TCSAFLUSH, &raw) == 0 {
                initial.rawModeActive = true
            }
        }
        self.state = Mutex(initial)
        #endif
    }

    deinit {
        #if canImport(Darwin) || canImport(Glibc)
        state.withLock { s in
            if var original = s.originalTermios {
                tcsetattr(fd, TCSAFLUSH, &original)
            }
        }
        #endif
        if ownsDescriptor {
            close(fd)
        }
    }

    /// Reads a single byte from the underlying file descriptor, blocking until available.
    /// - Returns: The byte read, or `nil` on EOF or error.
    public func readByte() -> UInt8? {
        var byte: UInt8 = 0
        let count = read(fd, &byte, 1)
        guard count == 1 else { return nil }
        return byte
    }

    /// Whether raw terminal mode was successfully activated.
    public var isRawMode: Bool {
        #if canImport(Darwin) || canImport(Glibc)
        return state.withLock { $0.rawModeActive }
        #else
        return false
        #endif
    }
}
