// App.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// The top-level Elm-architecture runtime for a terminal application.
///
/// `App` ties together model, update, view, subscriptions, and event mapping
/// into a self-contained program that drives a raw terminal session.
///
/// ```swift
/// struct MyModel: Sendable { var count = 0 }
/// enum Msg: Sendable { case quit }
///
/// let app = App<MyModel, Msg>(
///     initialModel: MyModel(),
///     update: { model, msg in
///         // handle messages, return commands
///         return [.none]
///     },
///     view: { model in { frame in
///         frame.writeText("Hello", x: 0, y: 0)
///     }},
///     mapEvent: { event in
///         if case .key(.character("q")) = event { return Msg.quit }
///         return nil
///     }
/// )
/// try await app.run()
/// ```
public struct App<Model: Sendable, Message: Sendable>: Sendable {
    private let initialModel: Model
    private let update: @Sendable (inout Model, Message) -> [Cmd<Message>]
    private let view: @Sendable (Model) -> (inout Frame) -> Void
    private let subscriptions: (@Sendable (Model) -> [Subscription<Message>])?
    private let mapEvent: (@Sendable (Event) -> Message?)?

    /// Creates an app with the given Elm-architecture components.
    /// - Parameters:
    ///   - initialModel: The starting state.
    ///   - update: Processes messages and returns commands.
    ///   - view: Renders the model into a frame.
    ///   - subscriptions: Returns active subscriptions based on the model.
    ///   - mapEvent: Maps raw terminal events to application messages.
    public init(
        initialModel: Model,
        update: @Sendable @escaping (inout Model, Message) -> [Cmd<Message>],
        view: @Sendable @escaping (Model) -> (inout Frame) -> Void,
        subscriptions: (@Sendable (Model) -> [Subscription<Message>])? = nil,
        mapEvent: (@Sendable (Event) -> Message?)? = nil
    ) {
        self.initialModel = initialModel
        self.update = update
        self.view = view
        self.subscriptions = subscriptions
        self.mapEvent = mapEvent
    }

    /// Starts the application event loop.
    ///
    /// Enters raw mode, switches to the alternate screen, and begins
    /// processing events until a ``Cmd/quit`` command is returned.
    ///
    /// - Note: Stub implementation — returns immediately without starting the loop.
    /// - Throws: Any error from terminal setup or teardown.
    public func run() async throws { }  // STUB: no-op
}
