// Component.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A self-contained UI component with its own model, update, and view.
///
/// Components encapsulate child state and translate child messages into
/// parent messages, enabling composition of ``App`` programs.
///
/// ```swift
/// struct CounterModel: Sendable { var count = 0 }
/// enum CounterMsg: Sendable { case increment, decrement }
/// enum ParentMsg: Sendable { case counter(CounterMsg) }
///
/// var counter = Component<CounterModel, CounterMsg, ParentMsg>(
///     initialModel: CounterModel(count: 0),
///     update: { model, msg in
///         switch msg {
///         case .increment: model.count += 1
///         case .decrement: model.count -= 1
///         }
///         return []
///     },
///     view: { model in { frame in
///         frame.writeText("Count: \(model.count)", x: 0, y: 0)
///     }},
///     toParent: { .counter($0) }
/// )
/// ```
public struct Component<Model: Sendable, Message: Sendable, ParentMessage: Sendable>: Sendable {
    /// The component's current model.
    public var model: Model

    /// The update function that processes messages and returns commands.
    public let update: @Sendable (inout Model, Message) -> [Cmd<Message>]

    /// The view function that renders the model into a frame.
    public let view: @Sendable (Model) -> (inout Frame) -> Void

    /// Maps child messages to parent messages.
    public let toParent: @Sendable (Message) -> ParentMessage

    /// Creates a component with the given initial model, update, view, and parent mapping.
    /// - Parameters:
    ///   - initialModel: The starting state for this component.
    ///   - update: A function that processes messages and returns commands.
    ///   - view: A function that produces a rendering closure from the model.
    ///   - toParent: A function that maps child messages to parent messages.
    public init(
        initialModel: Model,
        update: @Sendable @escaping (inout Model, Message) -> [Cmd<Message>],
        view: @Sendable @escaping (Model) -> (inout Frame) -> Void,
        toParent: @Sendable @escaping (Message) -> ParentMessage
    ) {
        self.model = initialModel
        self.update = update
        self.view = view
        self.toParent = toParent
    }

    /// Sends a message to this component's update function and returns
    /// the resulting commands mapped to the parent message type.
    ///
    /// - Parameter message: The child message to process.
    /// - Returns: Commands mapped to the parent message type.
    public mutating func send(_ message: Message) -> [Cmd<ParentMessage>] {
        let childCmds = update(&model, message)
        return childCmds.map { childCmd in
            mapCmd(childCmd)
        }
    }

    /// Maps a child command to a parent command by wrapping messages through ``toParent``.
    private func mapCmd(_ cmd: Cmd<Message>) -> Cmd<ParentMessage> {
        switch cmd.kind {
        case .empty:
            return .none
        case .terminate:
            return .quit
        case .task(let work):
            return .task { [toParent] in toParent(await work()) }
        case .taskWithError(let work, let onErr):
            return .task(
                perform: { [toParent] in toParent(try await work()) },
                onError: { [toParent] in toParent(onErr($0)) }
            )
        case .batch(let cmds):
            let mapped = cmds.map { mapCmd($0) }
            return .batch(mapped)
        case .delay(let duration, let msg):
            return .delay(duration, then: toParent(msg))
        }
    }

    /// Renders this component into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        let renderClosure = view(model)
        renderClosure(&frame)
    }
}
