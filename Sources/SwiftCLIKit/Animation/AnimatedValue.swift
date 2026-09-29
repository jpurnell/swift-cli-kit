// AnimatedValue.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Interpolates between a start and end value based on animation progress.
///
/// `AnimatedValue` pairs a `from` and `to` value with an `Animation`,
/// producing the current interpolated value at any given instant.
///
/// ```swift
/// var animated = AnimatedValue(from: 0.0, to: 100.0,
///     animation: Animation(duration: .seconds(1), easing: .linear))
/// animated.start()
/// let current = animated.value(at: .now) // 0.0...100.0
/// ```
public struct AnimatedValue<T: Sendable>: Sendable {
    /// The starting value.
    public var from: T
    /// The ending value.
    public var to: T
    /// The animation driving the interpolation.
    public var animation: Animation

    /// Creates an animated value interpolating between `from` and `to`.
    /// - Parameters:
    ///   - from: The starting value.
    ///   - to: The ending value.
    ///   - animation: The animation controlling progress.
    ///   - reduceMotion: When `true`, replaces animation with zero-duration for motion-sensitive users.
    public init(from: T, to: T, animation: Animation, reduceMotion: Bool = false) {
        self.from = from
        self.to = to
        self.animation = reduceMotion
            ? Animation(duration: .zero, easing: .linear)
            : animation
    }

    /// Start the underlying animation.
    /// - Parameter now: The current time (default: `.now`).
    public mutating func start(at now: ContinuousClock.Instant = .now) {
        animation.start(at: now)
    }
}

extension AnimatedValue where T: BinaryFloatingPoint {
    /// Current interpolated value based on animation progress.
    /// - Parameter now: The current time.
    /// - Returns: A value between `from` and `to` (inclusive).
    public func value(at now: ContinuousClock.Instant) -> T {
        let progress = T(animation.progress(at: now))
        return from + (to - from) * progress
    }
}

extension AnimatedValue where T == Int {
    /// Current interpolated value (rounded) based on animation progress.
    /// - Parameter now: The current time.
    /// - Returns: An integer between `from` and `to` (inclusive).
    public func value(at now: ContinuousClock.Instant) -> Int {
        let progress = animation.progress(at: now)
        return from + Int((Double(to - from) * progress).rounded())
    }
}
