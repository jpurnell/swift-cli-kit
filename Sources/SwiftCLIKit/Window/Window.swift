// Window.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A floating rectangular panel that renders on top of the base view.
///
/// Windows are managed by ``WindowManager`` and rendered in Z-order onto the
/// shared ``CellBuffer``. Each window has its own render closure, position,
/// and optional shadow/modal properties.
///
/// ```swift
/// let window = Window(
///     id: "help",
///     rect: Rect(x: 10, y: 5, width: 40, height: 15),
///     zIndex: 10,
///     render: { frame in
///         frame.writeText("Help content here", x: 1, y: 1)
///     }
/// )
/// ```
public struct Window: Sendable, Identifiable {
    /// Unique identifier for this window.
    public var id: String
    /// Optional display title for the window.
    public var title: String?
    /// The position and size of the window in terminal coordinates.
    public var rect: Rect
    /// Layer ordering: higher values render on top of lower values.
    public var zIndex: Int
    /// The closure that renders this window's content into a frame.
    public var render: @Sendable (inout Frame) -> Void
    /// Optional drop-shadow configuration.
    public var shadow: Shadow?
    /// Whether this window is modal (dims background and captures focus).
    public var isModal: Bool

    /// Creates a new window.
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - title: Optional display title.
    ///   - rect: Position and size.
    ///   - zIndex: Layer order (default: 0).
    ///   - render: Closure that renders content into a frame.
    ///   - shadow: Optional shadow (default: nil).
    ///   - isModal: Whether the window is modal (default: false).
    public init(
        id: String,
        title: String? = nil,
        rect: Rect,
        zIndex: Int = 0,
        render: @escaping @Sendable (inout Frame) -> Void,
        shadow: Shadow? = nil,
        isModal: Bool = false
    ) {
        self.id = id
        self.title = title
        self.rect = rect
        self.zIndex = zIndex
        self.render = render
        self.shadow = shadow
        self.isModal = isModal
    }
}
