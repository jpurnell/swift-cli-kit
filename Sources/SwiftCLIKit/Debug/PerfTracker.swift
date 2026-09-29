// PerfTracker.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Collects per-frame timing data from the SwiftCLIKit render loop.
///
/// `PerfTracker` is designed to be called by the framework's run loop, not
/// by user code directly. When debug mode is enabled, the framework
/// instruments each frame with ``beginFrame()``/``endFrame()`` and records
/// individual phase durations.
///
/// ```swift
/// var tracker = PerfTracker()
/// tracker.beginFrame()
/// tracker.recordUpdateDuration(.milliseconds(1))
/// tracker.recordViewDuration(.milliseconds(3))
/// tracker.recordDiffCellCount(200)
/// tracker.endFrame()
/// print(tracker.currentFPS)
/// ```
public struct PerfTracker: Sendable {

    /// Number of frames retained for rolling averages.
    public static let historySize: Int = 60

    /// Frame times stored for the rolling window.
    private var frameTimes: [Duration]

    /// Timestamp of the most recent ``beginFrame()`` call.
    private var frameStartTime: ContinuousClock.Instant?

    /// Duration of the most recent update phase.
    private var _lastUpdateDuration: Duration

    /// Duration of the most recent view phase.
    private var _lastViewDuration: Duration

    /// Cell count from the most recent diff.
    private var _lastDiffCellCount: Int

    /// Total number of frames recorded.
    private var _totalFrameCount: Int

    /// Creates a new performance tracker with empty history.
    public init() {
        self.frameTimes = []
        self.frameStartTime = nil
        self._lastUpdateDuration = .zero
        self._lastViewDuration = .zero
        self._lastDiffCellCount = 0
        self._totalFrameCount = 0
    }

    /// Marks the start of a new frame.
    public mutating func beginFrame() {
        frameStartTime = ContinuousClock.now
    }

    /// Marks the end of the current frame and records total frame time.
    ///
    /// If ``beginFrame()`` was not called, records a zero-duration frame.
    public mutating func endFrame() {
        let elapsed: Duration
        if let start = frameStartTime {
            elapsed = ContinuousClock.now - start
        } else {
            elapsed = .zero
        }
        frameTimes.append(elapsed)
        if frameTimes.count > Self.historySize {
            frameTimes.removeFirst(frameTimes.count - Self.historySize)
        }
        _totalFrameCount += 1
        frameStartTime = nil
    }

    /// Records the duration of the model update phase.
    /// - Parameter duration: Time spent in the update function.
    public mutating func recordUpdateDuration(_ duration: Duration) {
        _lastUpdateDuration = duration
    }

    /// Records the duration of the view rendering phase.
    /// - Parameter duration: Time spent building the view.
    public mutating func recordViewDuration(_ duration: Duration) {
        _lastViewDuration = duration
    }

    /// Records the number of cells that changed in the diff.
    /// - Parameter count: Number of changed cells.
    public mutating func recordDiffCellCount(_ count: Int) {
        _lastDiffCellCount = max(count, 0)
    }

    /// Current frames per second, calculated from the rolling frame time window.
    ///
    /// Returns `0.0` when no frames have been recorded.
    public var currentFPS: Double {
        guard !frameTimes.isEmpty else { return 0.0 }
        let avg = averageFrameTime
        let totalAttos = Double(avg.components.seconds) * 1_000_000_000_000_000_000.0 + Double(avg.components.attoseconds)
        guard totalAttos > 0 else { return 0.0 }
        return 1_000_000_000_000_000_000.0 / totalAttos // fp-safety:disable
    }

    /// Average frame time over the rolling window.
    ///
    /// Returns `.zero` when no frames have been recorded.
    public var averageFrameTime: Duration {
        guard !frameTimes.isEmpty else { return .zero }
        var total: Duration = .zero
        for time in frameTimes {
            total += time
        }
        return total / frameTimes.count
    }

    /// Duration of the most recent update phase.
    public var lastUpdateDuration: Duration { _lastUpdateDuration }

    /// Duration of the most recent view rendering phase.
    public var lastViewDuration: Duration { _lastViewDuration }

    /// Number of cells that changed in the most recent diff.
    public var lastDiffCellCount: Int { _lastDiffCellCount }

    /// Total number of frames recorded since init or last reset.
    public var totalFrameCount: Int { _totalFrameCount }
}
