// List+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `List` widget into the semantic scene graph. The
// legacy render path is untouched. Selection and scroll are carried as data;
// the highlight appearance is a resolver decision (the `.focused` WidgetState).

import SwiftCLIKit

public extension List {
    /// Projects this list into a semantic ``Node``.
    ///
    /// Item texts and the selection/scroll state pass through; per-item styles and
    /// the highlight style are dropped in favor of a single `itemColor` role plus
    /// the resolver's `.focused` state styling.
    /// - Parameter itemColor: The color role for normal items (default: ``ColorRole/label``).
    /// - Returns: A ``Node/list(items:selectedIndex:scrollOffset:itemColor:showScrollbar:)`` node.
    func node(id: String = "", itemColor: ColorRole = .label) -> Node {
        .list(
            items: items.map { $0.text },
            selectedIndex: state.selectedIndex,
            scrollOffset: state.scrollOffset,
            itemColor: itemColor,
            showScrollbar: showScrollbar,
            id: id
        )
    }
}
