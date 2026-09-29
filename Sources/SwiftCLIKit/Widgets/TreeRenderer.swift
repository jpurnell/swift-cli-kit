// TreeRenderer.swift
// SwiftCLIKit
//
// The concrete, projected form of a tree (display strings, not generic values)
// plus the one flatten + guide + draw implementation — factored out of
// `Tree.render` so alternative renderers (SwiftGUIKit's CellRenderer) draw through
// the exact same routine and cannot drift. Generic `Tree<T>` projects into this
// form via its `renderNode` closure before drawing.

import Foundation

/// A tree node after projection: display text, identity, and children. Concrete
/// and `Equatable` — the generic value type and render closure are already
/// resolved away.
public struct TreeDisplayNode: Sendable, Equatable {
    /// The display text for this node.
    public let text: String
    /// The node's stable identifier (used for expansion and selection).
    public let id: String
    /// The child nodes.
    public let children: [TreeDisplayNode]

    /// Creates a projected tree node.
    public init(text: String, id: String, children: [TreeDisplayNode] = []) {
        self.text = text
        self.id = id
        self.children = children
    }
}

/// Draws a hierarchical tree: flattens visible nodes (respecting `expanded`),
/// draws indent + sibling guides + text, and highlights the selected row.
public enum TreeRenderer {

    /// Draws the tree into a frame.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - roots: The projected root nodes.
    ///   - expanded: The set of expanded node identifiers.
    ///   - selected: The selected node identifier, if any.
    ///   - scrollOffset: The first visible flattened-row index.
    ///   - indentWidth: Spaces per indent level.
    ///   - normalStyle: The style for non-selected rows.
    ///   - highlightStyle: The style for the selected row (filled to width).
    public static func draw(
        into frame: inout Frame,
        roots: [TreeDisplayNode],
        expanded: Set<String>,
        selected: String?,
        scrollOffset: Int,
        indentWidth: Int,
        normalStyle: CellStyle,
        highlightStyle: CellStyle
    ) {
        guard frame.rect.width > 0, frame.rect.height > 0 else { return }

        var flat: [(node: TreeDisplayNode, depth: Int)] = []
        func walk(_ nodes: [TreeDisplayNode], depth: Int) {
            guard !nodes.isEmpty else { return }   // base case: no children to flatten
            for node in nodes {
                flat.append((node, depth))
                if expanded.contains(node.id) { walk(node.children, depth: depth + 1) }
            }
        }
        walk(roots, depth: 0)
        guard !flat.isEmpty else { return }

        let visibleCount = frame.rect.height
        for rowIdx in 0..<visibleCount {
            let flatIdx = scrollOffset + rowIdx
            guard flatIdx < flat.count else { break }
            let (node, depth) = flat[flatIdx]
            let isSelected = (selected == node.id)
            let style = isSelected ? highlightStyle : normalStyle

            let indent = String(repeating: " ", count: depth * indentWidth)
            let guide: String
            if depth > 0 {
                guide = isLastSibling(in: flat, at: flatIdx, depth: depth) ? "└── " : "├── "
            } else {
                guide = ""
            }
            let text = indent + guide + node.text

            frame.writeText(text, x: 0, y: rowIdx, fg: style.fg, bg: style.bg, attributes: style.attributes)

            // Fill remaining cells for the selected row. Bounds-guard: text may be
            // wider than the frame (empty fill then).
            if isSelected {
                let fillStart = Swift.min(text.count, frame.rect.width)
                for fillX in fillStart..<frame.rect.width {
                    frame.setCell(x: fillX, y: rowIdx, cell: Cell(
                        character: " ", fg: style.fg, bg: style.bg, attributes: style.attributes
                    ))
                }
            }
        }
    }

    /// Determines if the node at `index` is the last sibling at its depth level.
    private static func isLastSibling(
        in flat: [(node: TreeDisplayNode, depth: Int)], at index: Int, depth: Int
    ) -> Bool {
        for nextIdx in (index + 1)..<flat.count {
            let nextDepth = flat[nextIdx].depth
            if nextDepth < depth { return true }
            if nextDepth == depth { return false }
        }
        return true
    }
}
