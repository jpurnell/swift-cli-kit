// TerminalSize.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(Darwin) || canImport(Glibc)
private struct ResizeState: Sendable {
    var callbacks: [ObjectIdentifier: @Sendable (TerminalSize) -> Void] = [:]
    var signalHandlerInstalled: Bool = false
}

private let resizeState = Mutex(ResizeState())

private func installSignalHandler() {
    resizeState.withLock { state in
        guard !state.signalHandlerInstalled else { return }
        state.signalHandlerInstalled = true
        signal(SIGWINCH) { _ in
            let size = TerminalSize.current()
            let callbacks = resizeState.withLock { $0.callbacks }
            for (_, callback) in callbacks {
                callback(size)
            }
        }
    }
}
#endif

/// The dimensions of the terminal window in columns and rows.
public struct TerminalSize: Sendable, Equatable {
    /// Number of character columns.
    public var columns: Int
    /// Number of character rows.
    public var rows: Int

    /// Creates a terminal size with the given dimensions.
    /// - Parameter columns: Column count. Defaults to 80.
    /// - Parameter rows: Row count. Defaults to 24.
    public init(columns: Int = 80, rows: Int = 24) {
        self.columns = columns
        self.rows = rows
    }

    /// Queries the OS for the current terminal size via `ioctl(TIOCGWINSZ)`.
    /// - Parameter fileDescriptor: The descriptor to query. Defaults to STDOUT.
    /// - Parameter fallback: Returned when the query fails (e.g. not a TTY).
    /// - Returns: The detected terminal size, or `fallback`.
    public static func current(
        fileDescriptor: Int32 = 1,  // STDOUT_FILENO
        fallback: TerminalSize = TerminalSize(columns: 80, rows: 24)
    ) -> TerminalSize {
        #if canImport(Darwin) || canImport(Glibc)
        var ws = winsize()
        guard ioctl(fileDescriptor, UInt(TIOCGWINSZ), &ws) == 0 else {
            return fallback
        }
        let cols = Int(ws.ws_col)
        let rows = Int(ws.ws_row)
        guard cols > 0, rows > 0 else { return fallback }
        return TerminalSize(columns: cols, rows: rows)
        #else
        return fallback
        #endif
    }

    /// Registers a callback to be invoked when the terminal window is resized (SIGWINCH).
    ///
    /// Hold the returned token for the lifetime of the subscription; the callback
    /// is automatically deregistered when the token is deallocated.
    /// - Parameter onChange: Called with the new size on each resize event.
    /// - Returns: A ``ResizeToken`` whose lifetime controls the subscription.
    public static func onResize(_ onChange: @escaping @Sendable (TerminalSize) -> Void) -> ResizeToken {
        let token = ResizeToken()
        let identifier = ObjectIdentifier(token)
        #if canImport(Darwin) || canImport(Glibc)
        resizeState.withLock { state in
            state.callbacks[identifier] = onChange
        }
        installSignalHandler()
        #endif
        token._identifier.withLock { $0 = identifier }
        return token
    }
}

/// An opaque token whose lifetime controls a SIGWINCH resize subscription.
/// Deallocation automatically deregisters the callback.
public final class ResizeToken: Sendable {
    fileprivate let _identifier = Mutex<ObjectIdentifier?>(nil)

    deinit {
        #if canImport(Darwin) || canImport(Glibc)
        guard let identifier = _identifier.withLock({ $0 }) else { return }
        resizeState.withLock { state in
            _ = state.callbacks.removeValue(forKey: identifier)
        }
        #endif
    }
}
