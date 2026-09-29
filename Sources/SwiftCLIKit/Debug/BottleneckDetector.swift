// BottleneckDetector.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Analyzes per-frame metrics and generates warnings when thresholds are exceeded.
///
/// `BottleneckDetector` runs after each frame and returns zero or more
/// warnings. These can be displayed in the overlay, logged, or ignored.
///
/// ```swift
/// let tracker = PerfTracker()
/// let detector = BottleneckDetector()
/// let warnings = detector.check(tracker: tracker)
/// for warning in warnings {
///     print("\(warning.kind.rawValue): exceeded threshold")
/// }
/// ```
public struct BottleneckDetector: Sendable {
    /// Maximum acceptable duration for the update (model) phase.
    public var updateThreshold: Duration

    /// Maximum acceptable duration for the view (rendering) phase.
    public var viewThreshold: Duration

    /// Maximum acceptable total frame duration.
    public var frameThreshold: Duration

    /// Creates a bottleneck detector with the given thresholds.
    /// - Parameters:
    ///   - updateThreshold: Max update duration (default: 1 ms).
    ///   - viewThreshold: Max view duration (default: 5 ms).
    ///   - frameThreshold: Max frame duration (default: 16 ms).
    public init(
        updateThreshold: Duration = .milliseconds(1),
        viewThreshold: Duration = .milliseconds(5),
        frameThreshold: Duration = .milliseconds(16)
    ) {
        self.updateThreshold = updateThreshold
        self.viewThreshold = viewThreshold
        self.frameThreshold = frameThreshold
    }

    /// Checks the current tracker state against all thresholds.
    ///
    /// Returns an empty array if all metrics are within bounds.
    /// - Parameter tracker: The performance tracker to inspect.
    /// - Returns: An array of warnings for exceeded thresholds.
    public func check(tracker: PerfTracker) -> [BottleneckWarning] {
        var warnings: [BottleneckWarning] = []

        if tracker.lastUpdateDuration > updateThreshold {
            warnings.append(BottleneckWarning(
                kind: .slowUpdate,
                duration: tracker.lastUpdateDuration,
                threshold: updateThreshold
            ))
        }

        if tracker.lastViewDuration > viewThreshold {
            warnings.append(BottleneckWarning(
                kind: .slowView,
                duration: tracker.lastViewDuration,
                threshold: viewThreshold
            ))
        }

        if tracker.averageFrameTime > frameThreshold {
            warnings.append(BottleneckWarning(
                kind: .droppedFrame,
                duration: tracker.averageFrameTime,
                threshold: frameThreshold
            ))
        }

        return warnings
    }
}

/// A warning generated when a performance metric exceeds its threshold.
public struct BottleneckWarning: Sendable {
    /// What kind of bottleneck was detected.
    public var kind: WarningKind

    /// The actual measured duration.
    public var duration: Duration

    /// The threshold that was exceeded.
    public var threshold: Duration

    /// Categories of performance bottlenecks.
    public enum WarningKind: String, Sendable {
        /// The update (model) phase took too long.
        case slowUpdate
        /// The view (rendering) phase took too long.
        case slowView
        /// The total frame exceeded the target frame budget.
        case droppedFrame
    }
}
