// Block+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Block` container into the semantic scene graph. A
// Block wraps a child, so its projection takes the child node. The legacy render
// path is untouched.

import SwiftCLIKit

public extension Block {
    /// Projects this block (with its wrapped child) into a semantic ``Node``.
    /// - Parameter child: The node rendered inside the block's border.
    /// - Returns: A ``Node/block(title:borders:boxDrawing:titleAlignment:child:)`` node.
    func node(child: Node) -> Node {
        .block(title: title, borders: borders, boxDrawing: boxDrawing,
               titleAlignment: titleAlignment, child: child)
    }
}
