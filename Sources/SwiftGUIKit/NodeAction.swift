// NodeAction.swift
// SwiftGUIKit
//
// The universal interaction event. Interactive nodes carry a stable `id`; a
// renderer wires its controls to emit a `NodeAction`, and the app handles it to
// update its model and re-derive the scene (Model → View → Action, TEA-style).
//
// This keeps the scene graph a pure `Equatable` value tree — actions are values,
// not closures baked into `Node`, and there is no per-app `Message` generic.

/// An interaction emitted by a rendered node.
public enum NodeAction: Sendable, Equatable {
    /// A toggle/checkbox with `id` changed to `value`.
    case toggled(id: String, _ value: Bool)
    /// A text field/area with `id` changed to `value`.
    case textChanged(id: String, _ value: String)
    /// A field with `id` was submitted (e.g. Enter).
    case submitted(id: String)
    /// A single-select control with `id` selected index `index`.
    case selected(id: String, _ index: Int)
    /// A node-identity selection (e.g. a tree): the control with `id` selected the
    /// node whose stable identifier is `nodeID`. Distinct from ``selected(id:_:)``
    /// because a tree selects by node identity, not row index.
    case nodeSelected(id: String, _ nodeID: String)
}
