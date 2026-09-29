// RadioGroup+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `RadioGroup` widget into the semantic scene graph.
// The legacy render path is untouched. Focus is deferred (interaction phase).

import SwiftCLIKit

public extension RadioGroup {
    /// Projects this radio group into a semantic ``Node``.
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/radioGroup(options:selectedIndex:color:)`` node.
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .radioGroup(options: options, selectedIndex: selectedIndex, id: id, color: color)
    }
}
