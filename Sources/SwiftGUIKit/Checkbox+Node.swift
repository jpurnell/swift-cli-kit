// Checkbox+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Checkbox` widget into the semantic scene graph. The
// legacy render path is untouched. Focus is not carried — interaction/focus is a
// later phase; the node renders the resting (unfocused) appearance.

import SwiftCLIKit

public extension Checkbox {
    /// Projects this checkbox into a semantic ``Node``.
    /// - Parameters:
    ///   - id: A stable identifier for interaction (default: empty = non-interactive).
    ///   - color: The text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/checkbox(isChecked:label:id:color:)`` node.
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .checkbox(isChecked: isChecked, label: label, id: id, color: color)
    }
}
