// Checkbox.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A boolean toggle checkbox widget.
///
/// ```swift
/// var cb = Checkbox(label: "Remember me")
/// cb.toggle()
/// // cb.isChecked == true
/// ```
public struct Checkbox: Sendable {
    /// Whether the checkbox is currently checked.
    public var isChecked: Bool
    /// The label displayed after the checkbox indicator.
    public var label: String

    /// Creates a checkbox widget.
    /// - Parameters:
    ///   - label: The label text.
    ///   - isChecked: The initial checked state.
    public init(label: String = "", isChecked: Bool = false) {
        self.label = label
        self.isChecked = isChecked
    }

    /// Toggles the checked state.
    public mutating func toggle() {
        isChecked.toggle()
    }

    /// Renders this checkbox into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - focused: Whether this checkbox currently has focus.
    public func render(into frame: inout Frame, focused: Bool) {
        let indicator = isChecked ? "[x]" : "[ ]"
        let attrs: CellAttributes = focused ? .bold : []
        let text = label.isEmpty ? indicator : "\(indicator) \(label)"
        frame.writeText(text, x: 0, y: 0, attributes: attrs)
    }
}
