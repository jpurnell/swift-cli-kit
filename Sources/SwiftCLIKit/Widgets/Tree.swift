// Tree.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A hierarchical tree widget that renders nested nodes with expand/collapse support.
///
/// `Tree` is generic over its node value type, allowing any `Sendable` model to be displayed.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let tree = Tree(
///     roots: [
///         Tree.TreeNode(value: "Root", children: [
///             Tree.TreeNode(value: "Child A", children: []),
///             Tree.TreeNode(value: "Child B", children: []),
///         ]),
///     ],
///     state: TreeState(),
///     renderNode: { $0 }
/// )
/// tree.render(into: &frame)
/// ```
public struct Tree<Node: Sendable>: Sendable {
    /// A node in a ``Tree`` widget.
    public struct TreeNode: Sendable {
        /// The value stored in this node.
        public var value: Node
        /// The child nodes.
        public var children: [TreeNode]
        /// A unique identifier for this node.
        public var id: String

        /// Creates a tree node.
        /// - Parameters:
        ///   - value: The value for this node.
        ///   - children: Child nodes (default: empty).
        ///   - id: A unique identifier (default: UUID string).
        public init(value: Node, children: [TreeNode] = [], id: String = UUID().uuidString) {
            self.value = value
            self.children = children
            self.id = id
        }
    }

    /// The root nodes of the tree.
    public var roots: [TreeNode]
    /// The current expand/collapse and selection state.
    public var state: TreeState
    /// A closure that produces display text for a node value.
    public var renderNode: @Sendable (Node) -> String
    /// The style applied to the selected node.
    public var highlightStyle: CellStyle
    /// The number of spaces used per indent level.
    public var indentWidth: Int

    /// Creates a tree widget.
    /// - Parameters:
    ///   - roots: The root nodes.
    ///   - state: The tree state (default: new state).
    ///   - renderNode: A closure that produces display text for a node value.
    ///   - highlightStyle: Style for the selected node (default: reverse video).
    ///   - indentWidth: Spaces per indent level (default: 2).
    public init(
        roots: [TreeNode],
        state: TreeState = TreeState(),
        renderNode: @escaping @Sendable (Node) -> String,
        highlightStyle: CellStyle = CellStyle(attributes: [.reverse]),
        indentWidth: Int = 2
    ) {
        self.roots = roots
        self.state = state
        self.renderNode = renderNode
        self.highlightStyle = highlightStyle
        self.indentWidth = indentWidth
    }

    /// Renders this tree into the given frame.
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        // Project generic values into concrete display nodes, then draw through
        // the shared TreeRenderer so alternative renderers cannot drift.
        func project(_ n: TreeNode) -> TreeDisplayNode {
            TreeDisplayNode(text: renderNode(n.value), id: n.id, children: n.children.map(project))
        }
        TreeRenderer.draw(
            into: &frame,
            roots: roots.map(project),
            expanded: state.expandedNodes,
            selected: state.selectedNode,
            scrollOffset: state.scrollOffset,
            indentWidth: indentWidth,
            normalStyle: CellStyle(),
            highlightStyle: highlightStyle
        )
    }
}

/// Expand/collapse, selection, and scroll state for a ``Tree`` widget.
public struct TreeState: Sendable, Equatable {
    /// The set of expanded node identifiers.
    public var expandedNodes: Set<String>
    /// The currently selected node identifier, or `nil` for no selection.
    public var selectedNode: String?
    /// The scroll offset (first visible row index).
    public var scrollOffset: Int

    /// Creates a tree state.
    /// - Parameters:
    ///   - expandedNodes: Initially expanded node IDs (default: empty).
    ///   - selectedNode: The selected node ID (default: nil).
    ///   - scrollOffset: The scroll offset (default: 0).
    public init(
        expandedNodes: Set<String> = [],
        selectedNode: String? = nil,
        scrollOffset: Int = 0
    ) {
        self.expandedNodes = expandedNodes
        self.selectedNode = selectedNode
        self.scrollOffset = scrollOffset
    }

    /// Toggles the expanded state of the given node.
    /// - Parameter nodeID: The identifier of the node to toggle.
    public mutating func toggle(_ nodeID: String) {
        if expandedNodes.contains(nodeID) {
            expandedNodes.remove(nodeID)
        } else {
            expandedNodes.insert(nodeID)
        }
    }

    /// Expands all nodes in the given tree by collecting all node IDs.
    /// - Parameter nodeIDs: All node IDs to expand.
    public mutating func expandAll(nodeIDs: [String]) {
        for id in nodeIDs {
            expandedNodes.insert(id)
        }
    }

    /// Collapses all nodes.
    public mutating func collapseAll() {
        expandedNodes.removeAll()
    }
}

// MARK: - AccessibleWidget

extension Tree: AccessibleWidget {
    /// An accessibility label describing the tree, including root count, selection, and expanded state.
    public var accessibilityLabel: AccessibilityLabel {
        let rootCount = roots.count == 1 ? "1 root" : "\(roots.count) roots"
        var label = "Tree with \(rootCount)"
        if let sel = state.selectedNode { label += ", selected: \(sel)" }
        let expanded = state.expandedNodes.count
        label += ", \(expanded) expanded"
        return AccessibilityLabel(
            role: .tree,
            label: label,
            hint: "Enter to expand/collapse, arrow keys to navigate",
            childCount: roots.count
        )
    }
}
