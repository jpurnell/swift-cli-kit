// SSHSessionRequestState.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-07-14.

import SwiftCLIKit
import NIOSSH

/// Accumulates the SSH channel requests that decide how a session behaves.
///
/// SSH clients negotiate a session through a short sequence of channel requests
/// before the program runs: an optional `pty-req` (pseudo-terminal allocation),
/// zero or more `window-change` resizes, and finally a `shell` or `exec` request
/// that starts the program. This type folds that sequence into three facts the
/// server needs:
///
/// - ``isInteractive`` — whether a PTY was allocated. This is the network analog
///   of an `isatty` check: only interactive sessions should receive
///   cursor/screen-control escapes. It drives ``SSHBackend/init(initialSize:isInteractive:outputHandler:)``.
/// - ``terminalSize`` — the client's negotiated dimensions.
/// - ``kind`` — whether the client asked for a `shell` or an `exec`.
///
/// Interactivity depends solely on PTY allocation, never on shell-vs-exec:
/// `ssh -tt host cmd` (exec **with** a PTY) is interactive, while `ssh -T host`
/// (shell **without** a PTY) is not.
///
/// ```swift
/// var state = SSHSessionRequestState()
/// state.allocatePseudoTerminal(columns: 120, rows: 40)  // pty-req
/// state.requestShell()                                  // shell
/// // state.isInteractive == true, state.terminalSize == 120x40
/// ```
public struct SSHSessionRequestState: Sendable, Equatable {

    /// The program the client asked the server to start.
    public enum Kind: Sendable, Equatable {
        /// No `shell` or `exec` request has been seen yet.
        case pending
        /// The client requested an interactive shell (`shell`).
        case shell
        /// The client requested command execution (`exec`).
        case exec
    }

    /// Whether the client allocated a pseudo-terminal via `pty-req`.
    public private(set) var ptyAllocated: Bool
    /// The client's negotiated terminal dimensions.
    public private(set) var terminalSize: TerminalSize
    /// Which program the client requested, if any yet.
    public private(set) var kind: Kind

    /// Whether the session is interactive — true exactly when a PTY was allocated.
    ///
    /// The SSH analog of `isatty`. Non-interactive sessions (no PTY) must not
    /// receive screen-control escapes, which would garble captured `exec` output.
    public var isInteractive: Bool { ptyAllocated }

    /// Creates a fresh, non-interactive session state.
    /// - Parameter defaultSize: The size used until a `pty-req`/`window-change`
    ///   negotiates one. Defaults to 80x24.
    public init(defaultSize: TerminalSize = TerminalSize()) {
        self.ptyAllocated = false
        self.terminalSize = defaultSize
        self.kind = .pending
    }

    /// Records a `pty-req`: marks the session interactive and, when the client
    /// supplied character dimensions, adopts them.
    ///
    /// A `pty-req` always allocates a PTY even when it carries only pixel
    /// dimensions; in that case the negotiated character size is left unchanged
    /// (a TUI cannot render in pixels). Non-positive dimensions are ignored,
    /// mirroring ``TerminalSize/current(fileDescriptor:fallback:)``.
    /// - Parameters:
    ///   - columns: Requested character columns.
    ///   - rows: Requested character rows.
    public mutating func allocatePseudoTerminal(columns: Int, rows: Int) {
        ptyAllocated = true
        applySize(columns: columns, rows: rows)
    }

    /// Records a `window-change`: updates the terminal size in place.
    ///
    /// Non-positive dimensions are ignored, preserving the prior size.
    /// - Parameters:
    ///   - columns: New character columns.
    ///   - rows: New character rows.
    public mutating func resize(columns: Int, rows: Int) {
        applySize(columns: columns, rows: rows)
    }

    /// Records a `shell` request.
    public mutating func requestShell() {
        kind = .shell
    }

    /// Records an `exec` request.
    public mutating func requestExec() {
        kind = .exec
    }

    /// Updates ``terminalSize`` only when both dimensions are positive.
    private mutating func applySize(columns: Int, rows: Int) {
        guard columns > 0, rows > 0 else { return }
        terminalSize = TerminalSize(columns: columns, rows: rows)
    }
}

extension SSHSessionRequestState {
    /// Folds a NIOSSH inbound channel-request event into this state.
    ///
    /// Bridges the raw ``SSHChannelRequestEvent`` payloads delivered as inbound
    /// user events to the decision core: `pty-req` and `window-change` update
    /// interactivity/size, while `shell`/`exec` record the program to start.
    /// - Parameter event: An inbound user event from the SSH child channel.
    /// - Returns: `true` when the event establishes the session (a `shell` or
    ///   `exec` request), signaling the caller to launch the program now.
    public mutating func apply(_ event: Any) -> Bool {
        switch event {
        case let pty as SSHChannelRequestEvent.PseudoTerminalRequest:
            allocatePseudoTerminal(
                columns: pty.terminalCharacterWidth,
                rows: pty.terminalRowHeight
            )
            return false
        case let change as SSHChannelRequestEvent.WindowChangeRequest:
            resize(columns: change.terminalCharacterWidth, rows: change.terminalRowHeight)
            return false
        case is SSHChannelRequestEvent.ShellRequest:
            requestShell()
            return true
        case is SSHChannelRequestEvent.ExecRequest:
            requestExec()
            return true
        default:
            return false
        }
    }
}
