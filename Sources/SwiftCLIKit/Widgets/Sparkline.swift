// Sparkline.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A sparkline widget that renders a series of data points as a miniature bar chart using braille or block characters.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let spark = Sparkline(data: [1.0, 3.0, 2.0, 5.0, 4.0])
/// spark.render(into: &frame)
/// ```
public struct Sparkline: Sendable {
    /// The data points to display.
    public var data: [Double]
    /// The style for the sparkline.
    public var style: CellStyle
    /// An optional maximum value for scaling. When `nil`, the maximum data value is used.
    public var max: Double?

    /// Creates a sparkline widget.
    /// - Parameters:
    ///   - data: The data points.
    ///   - style: The sparkline style (default: default style).
    ///   - max: Optional maximum value for scaling.
    public init(
        data: [Double],
        style: CellStyle = CellStyle(),
        max: Double? = nil
    ) {
        self.data = data
        self.style = style
        self.max = max
    }

    /// Renders this sparkline into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        // Geometry is owned by SparklineGeometry so alternative renderers cannot
        // drift from this output.
        SparklineGeometry(data: data, max: max, width: frame.rect.width, height: frame.rect.height)
            .draw(into: &frame, style: style)
    }
}
