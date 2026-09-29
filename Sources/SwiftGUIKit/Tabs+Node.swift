// Tabs+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Tabs` widget into the semantic scene graph. The
// legacy render path is untouched.

import SwiftCLIKit

public extension Tabs {
    /// Projects this tab bar into a semantic ``Node``.
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/tabs(titles:activeIndex:separator:underline:color:)`` node.
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .tabs(titles: titles, activeIndex: activeIndex, separator: separator, underline: underline, id: id, color: color)
    }
}
