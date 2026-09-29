// Animation.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A duration-based animation tracker with start/progress/complete lifecycle.
///
/// `Animation` is a passive value type that does not own threads or timers.
/// Progress is calculated from `ContinuousClock` elapsed time, making it
/// frame-rate independent and deterministically testable.
///
/// ```swift
/// var anim = Animation(duration: .seconds(1), easing: .easeInOut)
/// anim.start()
/// let progress = anim.progress(at: .now) // 0.0...1.0 (eased)
/// ```
public struct Animation: Sendable {
    /// Total duration of the animation (excluding delay).
    public var duration: Duration
    /// Easing curve applied to the linear progress.
    public var easing: Easing
    /// Delay before the animation begins after starting.
    public var delay: Duration
    /// The instant the animation was started, or `nil` if not yet started.
    public private(set) var startTime: ContinuousClock.Instant?

    /// Creates an animation with the given duration and easing.
    /// - Parameters:
    ///   - duration: How long the animation runs.
    ///   - easing: The easing curve to apply (default: `.easeInOut`).
    ///   - delay: Time to wait after `start()` before progressing (default: `.zero`).
    public init(
        duration: Duration,
        easing: Easing = .easeInOut,
        delay: Duration = .zero
    ) {
        self.duration = duration
        self.easing = easing
        self.delay = delay
    }

    /// Mark the animation as started at the given instant.
    /// - Parameter now: The current time (default: `.now`).
    public mutating func start(at now: ContinuousClock.Instant = .now) {
        self.startTime = now
    }

    /// Raw linear progress (0.0 to 1.0) without easing applied.
    /// - Parameter now: The current time.
    /// - Returns: Linear progress, or 0.0 if not started or in delay.
    public func linearProgress(at now: ContinuousClock.Instant) -> Double {
        guard let startTime else { return 0.0 }

        let elapsed = now - startTime
        let delaySeconds = durationToSeconds(delay)
        let elapsedSeconds = durationToSeconds(elapsed)

        guard elapsedSeconds >= delaySeconds else { return 0.0 }

        let activeSeconds = elapsedSeconds - delaySeconds
        let totalSeconds = durationToSeconds(duration)

        guard totalSeconds > 0.0 else { return 1.0 }

        return Swift.min(Swift.max(activeSeconds / totalSeconds, 0.0), 1.0)
    }

    /// Calculate the current progress (0.0 to 1.0, eased) at the given time.
    /// Returns 0.0 if not yet started or still in delay period.
    /// Returns 1.0 if past duration.
    /// - Parameter now: The current time.
    /// - Returns: Eased progress value.
    public func progress(at now: ContinuousClock.Instant) -> Double {
        let linear = linearProgress(at: now)
        return easing.apply(linear)
    }

    /// Whether the animation has completed (past duration).
    public var isComplete: Bool {
        guard let startTime else { return false }
        let now = ContinuousClock.now
        let elapsed = now - startTime
        let totalSeconds = durationToSeconds(delay) + durationToSeconds(duration)
        return durationToSeconds(elapsed) >= totalSeconds
    }

    /// Whether the animation has been started.
    public var isRunning: Bool {
        startTime != nil
    }

    // MARK: - Private Helpers

    private func durationToSeconds(_ d: Duration) -> Double {
        let components = d.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000.0
    }
}
