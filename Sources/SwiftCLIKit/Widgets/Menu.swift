// Menu.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A menu widget that renders a vertical list of selectable items with optional key hints.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let menu = Menu(
///     items: [
///         Menu.MenuItem(label: "New File", keyHint: "Ctrl+N"),
///         Menu.MenuItem(label: "Open...", keyHint: "Ctrl+O"),
///         Menu.MenuItem(label: "Disabled", enabled: false),
///     ],
///     selectedIndex: 0
/// )
/// menu.render(into: &frame)
/// ```
public struct Menu: Sendable {
    /// A single item in a ``Menu`` widget.
    public struct MenuItem: Sendable, Equatable {
        /// The label text.
        public var label: String
        /// An optional keyboard shortcut hint shown right-aligned.
        public var keyHint: String?
        /// Whether this item is selectable.
        public var enabled: Bool

        /// Creates a menu item.
        /// - Parameters:
        ///   - label: The label text.
        ///   - keyHint: Optional keyboard shortcut hint.
        ///   - enabled: Whether the item is selectable (default: true).
        public init(label: String, keyHint: String? = nil, enabled: Bool = true) {
            self.label = label
            self.keyHint = keyHint
            self.enabled = enabled
        }
    }

    /// The menu items.
    public var items: [MenuItem]
    /// The index of the currently selected item.
    public var selectedIndex: Int
    /// The style for the selected item.
    public var highlightStyle: CellStyle
    /// The style for disabled items.
    public var disabledStyle: CellStyle

    /// Creates a menu widget.
    /// - Parameters:
    ///   - items: The menu items.
    ///   - selectedIndex: The selected item index (default: 0).
    ///   - highlightStyle: Style for the selected item (default: reverse video).
    ///   - disabledStyle: Style for disabled items (default: dim).
    public init(
        items: [MenuItem],
        selectedIndex: Int = 0,
        highlightStyle: CellStyle = CellStyle(attributes: [.reverse]),
        disabledStyle: CellStyle = CellStyle(attributes: [.dim])
    ) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.highlightStyle = highlightStyle
        self.disabledStyle = disabledStyle
    }

    /// Renders this menu into the given frame.
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        // Drawing is owned by MenuRenderer so alternative renderers cannot drift.
        // The legacy widget truncates silently (no overflow indicator).
        MenuRenderer.draw(
            into: &frame,
            items: items.map { ($0.label, $0.keyHint, $0.enabled) },
            selectedIndex: selectedIndex,
            normalStyle: CellStyle(),
            highlightStyle: highlightStyle,
            disabledStyle: disabledStyle,
            showOverflow: false
        )
    }
}

// MARK: - AccessibleWidget

extension Menu: AccessibleWidget {
    /// An accessibility label describing the menu, including item count and currently selected item.
    public var accessibilityLabel: AccessibilityLabel {
        let count = items.count
        let selected = selectedIndex < count ? items[selectedIndex].label : ""
        return AccessibilityLabel(
            role: .menu,
            label: "Menu with \(count) items, selected: \(selected)",
            hint: "Enter to activate, arrow keys to navigate",
            childCount: count
        )
    }
}
