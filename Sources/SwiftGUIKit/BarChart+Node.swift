// BarChart+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `BarChart` widget into the semantic scene graph.
// The legacy render path is untouched.

import SwiftCLIKit

public extension BarChart {
    /// Projects this bar chart into a semantic ``Node``.
    ///
    /// Each bar's label and value pass through; per-bar styles are dropped in
    /// favor of a single `color` role (the node is monochrome in v1). Layout
    /// params (`barWidth`, `barGap`, `max`, `showValues`) pass through unchanged.
    /// - Parameter color: The color role for the bars (default: ``ColorRole/accent``).
    /// - Returns: A ``Node/barChart(bars:barWidth:barGap:max:showValues:color:)`` node.
    func node(color: ColorRole = .accent) -> Node {
        .barChart(
            bars: bars.map { BarValue(label: $0.label, value: $0.value) },
            barWidth: barWidth,
            barGap: barGap,
            max: max,
            showValues: showValues,
            color: color
        )
    }
}
