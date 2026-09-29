// BarChart.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A vertical bar chart widget that renders labeled bars with proportional heights.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let chart = BarChart(bars: [
///     BarChart.Bar(label: "A", value: 10),
///     BarChart.Bar(label: "B", value: 20),
///     BarChart.Bar(label: "C", value: 15),
/// ])
/// chart.render(into: &frame)
/// ```
public struct BarChart: Sendable {
    /// A single bar in a ``BarChart`` widget.
    public struct Bar: Sendable, Equatable {
        /// The label displayed below the bar.
        public var label: String
        /// The numeric value determining bar height.
        public var value: Double
        /// The style for this bar.
        public var style: CellStyle

        /// Creates a bar.
        /// - Parameters:
        ///   - label: The label text.
        ///   - value: The numeric value.
        ///   - style: The bar style (default: default style).
        public init(label: String, value: Double, style: CellStyle = CellStyle()) {
            self.label = label
            self.value = value
            self.style = style
        }
    }

    /// The bars to display.
    public var bars: [Bar]
    /// The width of each bar in columns.
    public var barWidth: Int
    /// The gap between bars in columns.
    public var barGap: Int
    /// An optional maximum value for scaling. When `nil`, the maximum bar value is used.
    public var max: Double?
    /// Whether to display the numeric value above each bar.
    public var showValues: Bool

    /// Creates a bar chart widget.
    /// - Parameters:
    ///   - bars: The bars to display.
    ///   - barWidth: The width of each bar (default: 3).
    ///   - barGap: The gap between bars (default: 1).
    ///   - max: Optional maximum value for scaling.
    ///   - showValues: Whether to show values above bars (default: false).
    public init(
        bars: [Bar],
        barWidth: Int = 3,
        barGap: Int = 1,
        max: Double? = nil,
        showValues: Bool = false
    ) {
        self.bars = bars
        self.barWidth = barWidth
        self.barGap = barGap
        self.max = max
        self.showValues = showValues
    }

    /// Renders this bar chart into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        // The drawing logic is owned by BarChartRenderer so alternative renderers
        // cannot drift from this output. Each bar keeps its own style here.
        BarChartRenderer.draw(
            into: &frame,
            bars: bars.map { ($0.label, $0.value) },
            barWidth: barWidth,
            barGap: barGap,
            max: max,
            showValues: showValues,
            style: { bars[$0].style }
        )
    }
}
