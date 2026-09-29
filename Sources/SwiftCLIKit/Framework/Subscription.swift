// Subscription.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A long-lived event source that produces messages over time.
///
/// Subscriptions are declared as a function of the current model. The ``App``
/// runtime starts and stops them automatically when the returned set changes.
///
/// ```swift
/// struct Model: Sendable { var timerRunning = true }
/// enum Msg: Sendable { case tick }
///
/// func subscriptions(model: Model) -> [Subscription<Msg>] {
///     guard model.timerRunning else { return [] }
///     return [.timer(key: "tick", every: .seconds(1), message: { .tick })]
/// }
/// ```
public struct Subscription<Message: Sendable>: Sendable {
    /// A unique identifier for this subscription, used for lifecycle management.
    public var key: String

    /// The internal representation of the subscription's intent.
    internal enum Kind: Sendable {
        /// No subscription (placeholder).
        case empty
        /// A repeating timer that fires at the given interval.
        case timer(Duration, @Sendable () -> Message)
        /// An async stream that yields messages until nil.
        case asyncStream(@Sendable () async -> Message?)
    }

    /// The kind of subscription this value represents.
    internal let kind: Kind

    private init(key: String, kind: Kind) {
        self.key = key
        self.kind = kind
    }

    /// Creates a timer subscription that fires at a regular interval.
    /// - Parameters:
    ///   - key: Unique identifier for lifecycle management.
    ///   - interval: The time between ticks.
    ///   - message: A closure that produces the message on each tick.
    /// - Returns: A timer subscription.
    public static func timer(
        key: String,
        every interval: Duration,
        message: @Sendable @escaping () -> Message
    ) -> Subscription {
        Subscription(key: key, kind: .timer(interval, message))
    }

    /// Creates a stream subscription from an async producer closure.
    ///
    /// The producer is called repeatedly. Return `nil` to end the stream.
    /// - Parameters:
    ///   - key: Unique identifier for lifecycle management.
    ///   - producer: An async closure that yields the next message, or nil to stop.
    /// - Returns: A stream subscription.
    public static func stream(
        key: String,
        _ producer: @Sendable @escaping () async -> Message?
    ) -> Subscription {
        Subscription(key: key, kind: .asyncStream(producer))
    }

    /// A subscription that produces no events.
    public static var none: Subscription { Subscription(key: "", kind: Kind.empty) }
}
