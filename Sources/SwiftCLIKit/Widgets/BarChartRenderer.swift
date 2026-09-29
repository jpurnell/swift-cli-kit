// BarChartRenderer.swift
// SwiftCLIKit
//
// The one drawing implementation for a vertical bar chart, parameterized by a
// per-bar style lookup — factored out of `BarChart.render` so alternative
// renderers (SwiftGUIKit's CellRenderer) draw through the exact same routine and
// cannot drift. The legacy widget passes each bar's own style; a monochrome
// renderer passes one style for every bar.

import Foundation

/// Draws a vertical bar chart. Style is supplied per bar via a closure so the
/// same geometry serves both per-bar-styled and monochrome callers.
public enum BarChartRenderer {

    /// Draws the chart into a frame.
    /// - Parameters:
    ///   - frame: The frame to draw into.
    ///   - bars: The bars as `(label, value)` pairs.
    ///   - barWidth: The width of each bar in columns.
    ///   - barGap: The gap between bars in columns.
    ///   - max: An optional scaling maximum; when `nil`, the largest value is used.
    ///   - showValues: Whether to draw the numeric value above each bar.
    ///   - style: The style for bar `i`, by index.
    public static func draw(
        into frame: inout Frame,
        bars: [(label: String, value: Double)],
        barWidth: Int,
        barGap: Int,
        max: Double?,
        showValues: Bool,
        style: (Int) -> CellStyle
    ) {
        guard !bars.isEmpty else { return }

        let frameWidth = frame.rect.width
        let frameHeight = frame.rect.height
        guard frameHeight > 1 else { return }

        let labelRowCount = 1
        let valueRowCount = showValues ? 1 : 0
        let chartHeight = frameHeight - labelRowCount - valueRowCount
        guard chartHeight > 0 else { return }

        let maxVal = max ?? bars.max(by: { $0.value < $1.value })?.value ?? 1.0
        guard maxVal > 0 else {
            // Division safety: all values zero, just draw labels.
            for (i, bar) in bars.enumerated() {
                let xOffset = i * (barWidth + barGap)
                let labelX = xOffset + Swift.max((barWidth - bar.label.count) / 2, 0)
                let labelY = frameHeight - 1
                guard labelX < frameWidth else { continue }
                frame.writeText(bar.label, x: labelX, y: labelY)
            }
            return
        }

        for (i, bar) in bars.enumerated() {
            let xOffset = i * (barWidth + barGap)
            guard xOffset < frameWidth else { break }

            let ratio = Swift.min(Swift.max(bar.value / maxVal, 0.0), 1.0)
            let barHeight = Int(ratio * Double(chartHeight))
            let barStyle = style(i)

            // Draw bar columns from bottom of chart area upward.
            for row in 0..<barHeight {
                let y = frameHeight - 1 - labelRowCount - row
                guard y >= 0 else { break }
                for col in 0..<barWidth {
                    let x = xOffset + col
                    guard x < frameWidth else { break }
                    frame.setCell(x: x, y: y, cell: Cell(
                        character: "█",
                        fg: barStyle.fg,
                        bg: barStyle.bg,
                        attributes: barStyle.attributes
                    ))
                }
            }

            // Draw value above bar if requested.
            if showValues {
                let valueStr = String(Int(bar.value))
                let valueX = xOffset + Swift.max((barWidth - valueStr.count) / 2, 0)
                let valueY = frameHeight - 1 - labelRowCount - barHeight
                guard valueY >= 0 else { continue }
                frame.writeText(valueStr, x: valueX, y: valueY)
            }

            // Draw label centered at bottom row.
            let labelX = xOffset + Swift.max((barWidth - bar.label.count) / 2, 0)
            let labelY = frameHeight - 1
            guard labelX < frameWidth else { continue }
            frame.writeText(bar.label, x: labelX, y: labelY)
        }
    }
}
