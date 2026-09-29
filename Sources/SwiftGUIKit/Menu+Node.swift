// Menu+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Menu` widget into the semantic scene graph. The
// legacy render path is untouched.

import SwiftCLIKit

public extension Menu {
    /// Projects this menu into a semantic ``Node``.
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/menu(items:selectedIndex:color:)`` node.
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .menu(
            items: items.map { MenuEntry(label: $0.label, keyHint: $0.keyHint, enabled: $0.enabled) },
            selectedIndex: selectedIndex,
            id: id,
            color: color
        )
    }
}
