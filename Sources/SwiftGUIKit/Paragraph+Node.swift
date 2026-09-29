// Paragraph+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Paragraph` widget into the semantic scene graph. The
// legacy render path is untouched.

import SwiftCLIKit

public extension Paragraph {
    /// Projects this paragraph into a semantic ``Node``.
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/paragraph(text:alignment:wrap:color:)`` node.
    func node(color: ColorRole = .label) -> Node {
        .paragraph(text: text, alignment: alignment, wrap: wrap, color: color)
    }
}
