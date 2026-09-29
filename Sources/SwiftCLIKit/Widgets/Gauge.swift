// Gauge.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A horizontal gauge widget that displays a ratio as a filled/unfilled bar.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let gauge = Gauge(ratio: 0.75, label: "75%")
/// gauge.render(into: &frame)
/// ```
public struct Gauge: Sendable {
    /// The fill ratio from 0.0 (empty) to 1.0 (full).
    public var ratio: Double
    /// An optional label to display centered on the gauge.
    public var label: String?
    /// The style for the filled portion.
    public var filledStyle: CellStyle
    /// The style for the unfilled portion.
    public var unfilledStyle: CellStyle
    /// The character used for the filled portion.
    public var filledChar: Character
    /// The character used for the unfilled portion.
    public var unfilledChar: Character

    /// Creates a gauge widget.
    /// - Parameters:
    ///   - ratio: The fill ratio (0.0 to 1.0).
    ///   - label: Optional centered label text.
    ///   - filledStyle: Style for the filled portion (default: default style).
    ///   - unfilledStyle: Style for the unfilled portion (default: default style).
    ///   - filledChar: Character for the filled portion (default: "█").
    ///   - unfilledChar: Character for the unfilled portion (default: "░").
    public init(
        ratio: Double,
        label: String? = nil,
        filledStyle: CellStyle = CellStyle(),
        unfilledStyle: CellStyle = CellStyle(),
        filledChar: Character = "█",
        unfilledChar: Character = "░"
    ) {
        self.ratio = ratio
        self.label = label
        self.filledStyle = filledStyle
        self.unfilledStyle = unfilledStyle
        self.filledChar = filledChar
        self.unfilledChar = unfilledChar
    }

    /// Renders this gauge into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        let width = frame.rect.width
        guard width > 0 else { return }

        // Geometry and drawing are owned by GaugeGeometry so alternative
        // renderers cannot drift from this output.
        GaugeGeometry(width: width, ratio: ratio, labelLength: label?.count)
            .draw(
                into: &frame,
                filledChar: filledChar,
                filledStyle: filledStyle,
                unfilledChar: unfilledChar,
                unfilledStyle: unfilledStyle,
                label: label
            )
    }
}

// MARK: - AccessibleWidget

extension Gauge: AccessibleWidget {
    /// An accessibility label describing the gauge, including its label and current percentage value.
    public var accessibilityLabel: AccessibilityLabel {
        let pct = Int(Swift.max(0, Swift.min(1, ratio)) * 100)
        return AccessibilityLabel(
            role: .gauge,
            label: label ?? "Gauge",
            value: "\(pct)%"
        )
    }
}
