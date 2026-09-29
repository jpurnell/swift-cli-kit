// Dropdown.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A single-select dropdown widget that can expand to show all options.
///
/// ```swift
/// var dropdown = Dropdown(label: "Color", options: ["Red", "Green", "Blue"])
/// dropdown.toggle()   // expand
/// dropdown.selectNext() // highlight Green
/// ```
public struct Dropdown: Sendable {
    /// The available options.
    public var options: [String]
    /// The currently selected option index.
    public var selectedIndex: Int
    /// Whether the dropdown is currently expanded.
    public var isExpanded: Bool
    /// The label displayed to the left of the dropdown.
    public var label: String

    /// Creates a dropdown widget.
    /// - Parameters:
    ///   - label: The label text.
    ///   - options: The available options.
    ///   - selectedIndex: The initially selected index.
    public init(
        label: String = "",
        options: [String],
        selectedIndex: Int = 0
    ) {
        self.label = label
        self.options = options
        self.selectedIndex = options.isEmpty ? 0 : min(selectedIndex, options.count - 1)
        self.isExpanded = false
    }

    /// The currently selected option string, or nil if no options.
    public var selectedValue: String? {
        guard !options.isEmpty, selectedIndex >= 0, selectedIndex < options.count else {
            return nil
        }
        return options[selectedIndex]
    }

    /// Toggles the expanded/collapsed state.
    public mutating func toggle() {
        guard !options.isEmpty else { return }
        isExpanded.toggle()
    }

    /// Moves selection to the next option (wraps around).
    public mutating func selectNext() {
        guard !options.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % options.count
    }

    /// Moves selection to the previous option (wraps around).
    public mutating func selectPrevious() {
        guard !options.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + options.count) % options.count
    }

    /// Renders this dropdown into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - focused: Whether this dropdown currently has focus.
    public func render(into frame: inout Frame, focused: Bool) {
        let attrs: CellAttributes = focused ? .bold : []

        // Draw label
        var col = 0
        if !label.isEmpty {
            frame.writeText(label, x: 0, y: 0, attributes: attrs)
            col = label.count + 1
        }

        // Draw selected value or placeholder
        let display = selectedValue ?? "(none)"
        let arrow = isExpanded ? " \u{25B2}" : " \u{25BC}"
        frame.writeText("[\(display)\(arrow)]", x: col, y: 0, attributes: attrs)

        // If expanded, show options below
        if isExpanded {
            for (index, option) in options.enumerated() {
                let prefix = index == selectedIndex ? "> " : "  "
                let optionAttrs: CellAttributes = index == selectedIndex ? .reverse : []
                frame.writeText(
                    "\(prefix)\(option)",
                    x: col, y: 1 + index,
                    attributes: optionAttrs
                )
            }
        }
    }
}
