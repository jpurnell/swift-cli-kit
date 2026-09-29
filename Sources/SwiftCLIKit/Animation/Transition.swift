// Transition.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Enter/exit transition semantics wrapping an animation with visual effects.
///
/// Transitions manage the lifecycle of a widget's appearance and disappearance,
/// providing fade, slide, expand, and collapse effects.
///
/// ```swift
/// var transition = Transition(kind: .fade, duration: .milliseconds(300))
/// transition.enter() // Begin fading in
/// let opacity = transition.opacity(at: .now) // 0.0...1.0
/// ```
public struct Transition: Sendable {
    /// The visual effect type for the transition.
    public enum Kind: Sendable, Equatable {
        /// Fade from transparent to opaque (enter) or opaque to transparent (exit).
        case fade // LIVE: public API
        /// Slide in from the left (enter) or out to the left (exit).
        case slideLeft
        /// Slide in from the right (enter) or out to the right (exit).
        case slideRight
        /// Slide in from above (enter) or out upward (exit).
        case slideUp
        /// Slide in from below (enter) or out downward (exit).
        case slideDown
        /// Expand from zero size to full (enter).
        case expand // LIVE: public API
        /// Collapse from full size to zero (exit).
        case collapse // LIVE: public API
    }

    /// The current phase of the transition lifecycle.
    public enum Phase: Sendable, Equatable {
        /// The widget is entering (appearing).
        case enter
        /// The widget is fully visible and stable.
        case active
        /// The widget is exiting (disappearing).
        case exit
    }

    /// The visual effect kind.
    public var kind: Kind
    /// The underlying animation driving the transition.
    public var animation: Animation
    /// The current lifecycle phase.
    public var phase: Phase

    /// Creates a transition with the given visual effect and timing.
    /// - Parameters:
    ///   - kind: The type of visual effect.
    ///   - duration: How long the transition takes.
    ///   - easing: The easing curve (default: `.easeInOut`).
    ///   - reduceMotion: When `true`, uses zero-duration animation for motion-sensitive users.
    public init(kind: Kind, duration: Duration, easing: Easing = .easeInOut, reduceMotion: Bool = false) {
        self.kind = kind
        self.animation = reduceMotion
            ? Animation(duration: .zero, easing: .linear)
            : Animation(duration: duration, easing: easing)
        self.phase = .enter
    }

    /// Begin the enter phase.
    /// - Parameter now: The current time (default: `.now`).
    public mutating func enter(at now: ContinuousClock.Instant = .now) {
        phase = .enter
        animation = Animation(duration: animation.duration, easing: animation.easing, delay: animation.delay)
        animation.start(at: now)
    }

    /// Begin the exit phase (reverses the animation).
    /// - Parameter now: The current time (default: `.now`).
    public mutating func exit(at now: ContinuousClock.Instant = .now) {
        phase = .exit
        animation = Animation(duration: animation.duration, easing: animation.easing, delay: animation.delay)
        animation.start(at: now)
    }

    /// Current opacity for fade transitions (0.0 to 1.0).
    /// - Parameter now: The current time.
    /// - Returns: Opacity value. For non-fade transitions, returns 1.0 during enter/active, 0.0 when exit completes.
    public func opacity(at now: ContinuousClock.Instant) -> Double {
        let progress = animation.progress(at: now)
        switch phase {
        case .enter:
            return progress
        case .active:
            return 1.0
        case .exit:
            return 1.0 - progress
        }
    }

    /// Current positional offset for slide transitions (in cells).
    /// - Parameters:
    ///   - now: The current time.
    ///   - dimension: The size of the container in the relevant axis (width for horizontal, height for vertical).
    /// - Returns: Offset in cells. Zero means fully positioned; negative or positive values indicate displacement.
    public func offset(at now: ContinuousClock.Instant, dimension: Int) -> Int {
        let progress = animation.progress(at: now)
        let remaining: Double

        switch phase {
        case .enter:
            remaining = 1.0 - progress
        case .active:
            return 0
        case .exit:
            remaining = progress
        }

        let offsetValue: Double
        switch kind {
        case .slideLeft:
            offsetValue = -Double(dimension) * remaining
        case .slideRight:
            offsetValue = Double(dimension) * remaining
        case .slideUp:
            offsetValue = -Double(dimension) * remaining
        case .slideDown:
            offsetValue = Double(dimension) * remaining
        default:
            return 0
        }

        return Int(offsetValue.rounded())
    }

    /// Whether the transition has fully completed its current phase.
    public var isComplete: Bool {
        animation.linearProgress(at: .now) >= 1.0
    }
}
