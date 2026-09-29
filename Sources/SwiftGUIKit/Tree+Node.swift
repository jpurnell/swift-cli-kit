// Tree+Node.swift
// SwiftGUIKit
//
// Projects the generic SwiftCLIKit `Tree<T>` into the semantic scene graph. This
// is the projection boundary: the generic value type and the `renderNode`
// closure are resolved into concrete display strings here, so the scene graph
// stays monomorphic and Equatable. The legacy render path is untouched.
//
// Note: `Tree`'s generic parameter is named `Node`, which shadows SwiftGUIKit's
// `Node` inside this extension — hence the explicit `SwiftGUIKit.Node` return type.

import SwiftCLIKit

public extension Tree {
    /// Projects this tree into a semantic ``SwiftGUIKit/Node``.
    ///
    /// `renderNode` is applied eagerly to every value, producing a concrete
    /// ``TreeDisplayNode`` tree of display strings; expansion, selection, scroll,
    /// and indent pass through as state.
    /// - Parameters:
    ///   - id: The interaction identifier (empty when non-interactive; the terminal
    ///     renderer ignores it, the SwiftUI renderer emits `.nodeSelected(id:_:)`).
    ///   - itemColor: The text color role (default: ``ColorRole/label``).
    /// - Returns: A ``SwiftGUIKit/Node/tree(roots:expanded:selected:scrollOffset:indentWidth:itemColor:id:)`` node.
    func node(id: String = "", itemColor: ColorRole = .label) -> SwiftGUIKit.Node {
        func project(_ n: TreeNode) -> TreeDisplayNode {
            TreeDisplayNode(text: renderNode(n.value), id: n.id, children: n.children.map(project))
        }
        return .tree(
            roots: roots.map(project),
            expanded: state.expandedNodes,
            selected: state.selectedNode,
            scrollOffset: state.scrollOffset,
            indentWidth: indentWidth,
            itemColor: itemColor,
            id: id
        )
    }
}
