// TestBackend.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// An in-memory terminal backend for headless testing.
///
/// `TestBackend` captures rendered buffers and allows injecting events
/// into the event stream without a real terminal.
///
/// ```swift
/// let backend = TestBackend(width: 80, height: 24)
/// await backend.inject(.key(.character("a")))
/// ```
public final class TestBackend: TerminalBackend, Sendable {
    private struct State: Sendable {
        var buffer: CellBuffer
        var history: [CellBuffer] = []
        var eventContinuation: AsyncStream<Event>.Continuation?
        var writtenOutput: [String] = []
        var isRawMode: Bool = false
        var isAlternateScreen: Bool = false
        var isMouseEnabled: Bool = false
        var isCursorHidden: Bool = false
    }

    private let state: LockedState<State>
    private let _eventStream: AsyncStream<Event>

    /// The width of the virtual terminal in columns.
    public let width: Int
    /// The height of the virtual terminal in rows.
    public let height: Int

    /// Creates a test backend with the given dimensions.
    /// - Parameters:
    ///   - width: Number of columns.
    ///   - height: Number of rows.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        var cont: AsyncStream<Event>.Continuation?
        self._eventStream = AsyncStream { cont = $0 }
        self.state = LockedState(State(
            buffer: CellBuffer(width: width, height: height),
            eventContinuation: cont
        ))
    }

    /// The current rendered buffer.
    public var currentBuffer: CellBuffer {
        state.withLock { $0.buffer }
    }

    /// Injects a single event into the event stream.
    /// - Parameter event: The event to inject.
    public func inject(_ event: Event) async {
        let cont = state.withLock { $0.eventContinuation }
        cont?.yield(event)
    }

    /// Injects a sequence of events with an optional delay between each.
    /// - Parameters:
    ///   - events: The events to inject in order.
    ///   - delay: The delay between each event (default: zero).
    public func injectSequence(_ events: [Event], delay: Duration = .zero) async {
        for event in events {
            let cont = state.withLock { $0.eventContinuation }
            cont?.yield(event)
            if delay > .zero {
                try? await Task.sleep(for: delay) // silent: best-effort delay between injected events; cancellation is acceptable
            }
        }
    }

    /// Waits for the next render cycle to complete.
    public func waitForRender() async {
        await Task.yield()
    }

    /// The async stream of events for consumption by the app runtime.
    public var eventStream: AsyncStream<Event> { _eventStream }

    /// All buffers that have been recorded with ``submitRender(_:)``, oldest first.
    public var renderHistory: [CellBuffer] {
        state.withLock { $0.history }
    }

    /// Clears the render history.
    public func clearHistory() {
        state.withLock { $0.history.removeAll() }
    }

    /// Records a rendered buffer as the current screen and appends it to ``renderHistory``.
    ///
    /// Nothing in the library calls this: ``App`` drives a real terminal, not a backend. A test
    /// renders a frame itself and records it here, then asserts on ``currentBuffer``.
    ///
    /// ```swift
    /// let backend = TestBackend(width: 4, height: 1)
    /// var frame = Frame(buffer: CellBuffer(width: 4, height: 1), rect: Rect(x: 0, y: 0, width: 4, height: 1))
    /// frame.writeText("ok", x: 0, y: 0)
    /// backend.submitRender(frame.cellBuffer)
    /// ```
    /// - Parameter buf: The buffer to record.
    public func submitRender(_ buf: CellBuffer) {
        state.withLock { state in
            state.buffer = buf
            state.history.append(buf)
        }
    }

    // MARK: - TerminalBackend Conformance

    /// Enters raw mode (no-op for test backend).
    public func enableRawMode() throws {
        state.withLock { $0.isRawMode = true }
    }

    /// Restores original terminal mode (no-op for test backend).
    public func disableRawMode() {
        state.withLock { $0.isRawMode = false }
    }

    /// Returns `nil` immediately (use ``inject(_:)`` for event-driven testing).
    public func readKey() -> Key? { nil }

    /// Returns the configured test terminal dimensions.
    public func terminalSize() -> TerminalSize {
        TerminalSize(columns: width, rows: height)
    }

    /// Records the string for later assertion via ``allWrittenOutput``.
    /// - Parameter string: The text that would be written to a real terminal.
    public func write(_ string: String) {
        state.withLock { $0.writtenOutput.append(string) }
    }

    /// Marks the alternate screen as active (no-op for test backend).
    public func enterAlternateScreen() {
        state.withLock { $0.isAlternateScreen = true }
    }

    /// Marks the alternate screen as inactive (no-op for test backend).
    public func leaveAlternateScreen() {
        state.withLock { $0.isAlternateScreen = false }
    }

    /// Marks mouse tracking as enabled (no-op for test backend).
    public func enableMouse() {
        state.withLock { $0.isMouseEnabled = true }
    }

    /// Marks mouse tracking as disabled (no-op for test backend).
    public func disableMouse() {
        state.withLock { $0.isMouseEnabled = false }
    }

    /// Marks the cursor as hidden (no-op for test backend).
    public func hideCursor() {
        state.withLock { $0.isCursorHidden = true }
    }

    /// Marks the cursor as visible (no-op for test backend).
    public func showCursor() {
        state.withLock { $0.isCursorHidden = false }
    }

    // MARK: - Test Inspection

    /// All strings that have been written through the ``write(_:)`` method.
    public var allWrittenOutput: [String] {
        state.withLock { $0.writtenOutput }
    }

    /// Whether raw mode is currently active.
    public var isRawMode: Bool {
        state.withLock { $0.isRawMode }
    }

    /// Whether the alternate screen buffer is active.
    public var isAlternateScreen: Bool {
        state.withLock { $0.isAlternateScreen }
    }

    /// Whether mouse tracking is enabled.
    public var isMouseEnabled: Bool {
        state.withLock { $0.isMouseEnabled }
    }

    /// Whether the cursor is hidden.
    public var isCursorHidden: Bool {
        state.withLock { $0.isCursorHidden }
    }
}
