// ProgressBar+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `ProgressBar` widget into the semantic scene graph.
// The legacy render path is untouched.

import SwiftCLIKit

public extension ProgressBar {
    /// Projects this progress bar into a semantic ``Node``.
    ///
    /// `current`/`total`/`showPercentage` pass through unchanged; the single
    /// `color` role (the widget is monochrome) is resolved per surface.
    /// - Parameter color: The color role for the bar (default: ``ColorRole/accent``).
    /// - Returns: A ``Node/progressBar(current:total:showPercentage:color:)`` node.
    func node(color: ColorRole = .accent) -> Node {
        .progressBar(current: current, total: total, showPercentage: showPercentage, color: color)
    }
}
