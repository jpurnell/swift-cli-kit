// Sparkline+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Sparkline` widget into the semantic scene graph.
// The legacy render path is untouched.

import SwiftCLIKit

public extension Sparkline {
    /// Projects this sparkline into a semantic ``Node``.
    ///
    /// `data`/`max` pass through unchanged; the single `color` role (the widget
    /// is monochrome) is resolved per surface.
    /// - Parameter color: The color role for the bars (default: ``ColorRole/accent``).
    /// - Returns: A ``Node/sparkline(data:max:color:)`` node.
    func node(color: ColorRole = .accent) -> Node {
        .sparkline(data: data, max: max, color: color)
    }
}
