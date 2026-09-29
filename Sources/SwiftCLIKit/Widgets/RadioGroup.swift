// RadioGroup.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A single-select radio button group widget.
///
/// ```swift
/// var group = RadioGroup(options: ["Small", "Medium", "Large"], selectedIndex: 1)
/// group.selectNext()
/// // group.selectedIndex == 2
/// ```
public struct RadioGroup: Sendable {
    /// The available options.
    public var options: [String]
    /// The currently selected option index.
    public var selectedIndex: Int

    /// Creates a radio group widget.
    /// - Parameters:
    ///   - options: The available options.
    ///   - selectedIndex: The initially selected index.
    public init(options: [String], selectedIndex: Int = 0) {
        self.options = options
        self.selectedIndex = options.isEmpty ? 0 : min(selectedIndex, options.count - 1)
    }

    /// The currently selected option string, or nil if no options.
    public var selectedValue: String? {
        guard !options.isEmpty, selectedIndex >= 0, selectedIndex < options.count else {
            return nil
        }
        return options[selectedIndex]
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

    /// Renders this radio group into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - focused: Whether this radio group currently has focus.
    public func render(into frame: inout Frame, focused: Bool) {
        let attrs: CellAttributes = focused ? .bold : []
        for (index, option) in options.enumerated() {
            let indicator = index == selectedIndex ? "(\u{25CF})" : "( )"
            frame.writeText(
                "\(indicator) \(option)",
                x: 0, y: index,
                attributes: attrs
            )
        }
    }
}
