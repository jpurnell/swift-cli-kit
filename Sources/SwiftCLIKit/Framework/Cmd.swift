// Cmd.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A command returned by an update function to describe a side effect.
///
/// Commands are declarative descriptions of asynchronous work. The ``App``
/// runtime interprets them; update functions never execute I/O directly.
///
/// ```swift
/// // The model and message types are yours; the framework only needs them to
/// // be Sendable.
/// struct CounterModel: Sendable { var count = 0 }
/// enum Msg: Sendable { case increment, fetchData }
/// func loadData() async -> Msg { .increment }
///
/// func update(model: inout CounterModel, message: Msg) -> [Cmd<Msg>] {
///     switch message {
///     case .increment:
///         model.count += 1
///         return [.none]
///     case .fetchData:
///         return [.task { await loadData() }]
///     }
/// }
/// ```
public struct Cmd<Message: Sendable>: Sendable {
    /// The internal representation of the command's intent.
    internal enum Kind: Sendable {
        /// No side effect.
        case empty
        /// Signal the app to terminate.
        case terminate
        /// An async task that produces a message.
        case task(@Sendable () async -> Message)
        /// An async throwing task with an error handler.
        case taskWithError(@Sendable () async throws -> Message, @Sendable (any Error) -> Message)
        /// A batch of commands to execute concurrently.
        case batch([Cmd])
        /// A delayed message delivery.
        case delay(Duration, Message)
    }

    /// The kind of command this value represents.
    internal let kind: Kind

    private init(kind: Kind) { self.kind = kind }

    /// Creates a command that performs an async task and returns a message.
    /// - Parameter work: The async closure to execute.
    /// - Returns: A command wrapping the task.
    public static func task(_ work: @Sendable @escaping () async -> Message) -> Cmd {
        Cmd(kind: .task(work))
    }

    /// Creates a command that performs a throwing async task with an error handler.
    /// - Parameters:
    ///   - perform: The async throwing closure to execute.
    ///   - onError: A closure that maps errors to messages.
    /// - Returns: A command wrapping the task.
    public static func task(
        perform: @Sendable @escaping () async throws -> Message,
        onError: @Sendable @escaping (any Error) -> Message
    ) -> Cmd {
        Cmd(kind: .taskWithError(perform, onError))
    }

    /// Batches multiple commands for concurrent execution.
    /// - Parameter cmds: The commands to batch.
    /// - Returns: A single command representing the batch.
    public static func batch(_ cmds: [Cmd]) -> Cmd { Cmd(kind: .batch(cmds)) }

    /// A command that performs no side effect.
    public static var none: Cmd { Cmd(kind: Kind.empty) }

    /// A command that signals the app to quit.
    public static var quit: Cmd { Cmd(kind: Kind.terminate) }

    /// Creates a command that delivers a message after a delay.
    /// - Parameters:
    ///   - duration: How long to wait before delivering.
    ///   - message: The message to deliver.
    /// - Returns: A command wrapping the delay.
    public static func delay(_ duration: Duration, then message: Message) -> Cmd {
        Cmd(kind: .delay(duration, message))
    }
}
