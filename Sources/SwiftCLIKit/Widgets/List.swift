// List.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A selectable list widget that renders items vertically with optional highlighting and scrolling.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let list = List(
///     items: [
///         List.Item(text: "Alpha"),
///         List.Item(text: "Beta", style: CellStyle(fg: .ansi8(.green))),
///     ],
///     state: ListState(selectedIndex: 0)
/// )
/// list.render(into: &frame)
/// ```
public struct List: Sendable {
    /// A single item in a ``List`` widget.
    public struct Item: Sendable, Equatable {
        /// The display text.
        public var text: String
        /// The style for this item.
        public var style: CellStyle

        /// Creates a list item.
        /// - Parameters:
        ///   - text: The display text.
        ///   - style: The cell style (default: default style).
        public init(text: String, style: CellStyle = CellStyle()) {
            self.text = text
            self.style = style
        }
    }

    /// The items to display.
    public var items: [Item]
    /// The current selection and scroll state.
    public var state: ListState
    /// The style applied to the selected item.
    public var highlightStyle: CellStyle
    /// Whether to show a scrollbar when content overflows.
    public var showScrollbar: Bool

    /// Creates a list widget.
    /// - Parameters:
    ///   - items: The items to display.
    ///   - state: The list state (default: new state).
    ///   - highlightStyle: Style for the selected item (default: reverse video).
    ///   - showScrollbar: Whether to show a scrollbar (default: false).
    public init(
        items: [Item],
        state: ListState = ListState(),
        highlightStyle: CellStyle = CellStyle(attributes: [.reverse]),
        showScrollbar: Bool = false
    ) {
        self.items = items
        self.state = state
        self.highlightStyle = highlightStyle
        self.showScrollbar = showScrollbar
    }

    /// Renders this list into the given frame.
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        // Drawing is owned by ListRenderer so alternative renderers cannot drift
        // from this output. Each item keeps its own style here.
        ListRenderer.draw(
            into: &frame,
            items: items.map { $0.text },
            state: state,
            normalStyle: { items[$0].style },
            highlightStyle: highlightStyle
        )
    }
}

/// Selection and scroll state for a ``List`` widget.
public struct ListState: Sendable, Equatable {
    /// The currently selected item index, or `nil` for no selection.
    public var selectedIndex: Int?
    /// The scroll offset (first visible item index).
    public var scrollOffset: Int

    /// Creates a list state.
    /// - Parameters:
    ///   - selectedIndex: The selected item index (default: nil).
    ///   - scrollOffset: The scroll offset (default: 0).
    public init(selectedIndex: Int? = nil, scrollOffset: Int = 0) {
        self.selectedIndex = selectedIndex
        self.scrollOffset = scrollOffset
    }

    /// Moves the selection to the next item, scrolling if necessary.
    /// - Parameters:
    ///   - itemCount: The total number of items.
    ///   - visibleItems: The number of items visible in the viewport.
    public mutating func selectNext(itemCount: Int, visibleItems: Int) {
        guard itemCount > 0 else { return }
        let current = selectedIndex ?? -1
        let next = min(current + 1, itemCount - 1)
        selectedIndex = next
        if next >= scrollOffset + visibleItems {
            scrollOffset = next - visibleItems + 1
        }
    }

    /// Moves the selection to the previous item, scrolling if necessary.
    public mutating func selectPrevious() {
        guard let current = selectedIndex else { return }
        let prev = max(current - 1, 0)
        selectedIndex = prev
        if prev < scrollOffset {
            scrollOffset = prev
        }
    }
}

// MARK: - AccessibleWidget

extension List: AccessibleWidget {
    /// An accessibility label describing the list, including item count and current selection.
    public var accessibilityLabel: AccessibilityLabel {
        let count = items.count == 1 ? "1 item" : "\(items.count) items"
        var label = "List with \(count)"
        if let sel = state.selectedIndex {
            let itemText = sel < items.count ? items[sel].text : ""
            label += ", selected: \(itemText)"
        }
        return AccessibilityLabel(
            role: .list,
            label: label,
            hint: "Use arrow keys to navigate",
            childCount: items.count
        )
    }
}
