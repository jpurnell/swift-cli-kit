// InlineGauge.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-05-07.

import Foundation

/// A string-based inline gauge widget that returns styled ANSI strings for use
/// with ``ScreenBuffer`` composition.
///
/// Unlike the Frame-based ``Gauge`` widget, `InlineGauge` produces self-contained
/// ANSI-escaped strings that can be embedded directly in terminal output or composed
/// into a ``ScreenBuffer``.
///
/// ```swift
/// // Simple bar: 50% filled, 40 columns wide
/// let bar = InlineGauge.render(current: 50, total: 100, width: 40)
///
/// // Bar with centered percentage label
/// let labeled = InlineGauge.renderWithLabel(current: 75, total: 100, width: 40)
/// ```
///
/// Every returned string is ANSI-self-contained: it resets all styling at the end,
/// and its visible width (as measured by ``ANSIStringMetrics/visibleLength(_:)``)
/// matches the requested `width` parameter exactly.
public struct InlineGauge: Sendable {

    // MARK: - Public API

    /// Renders an inline gauge bar as an ANSI-styled string.
    ///
    /// The returned string contains exactly `width` visible characters (filled + unfilled),
    /// with ANSI color escapes applied and a terminal reset appended at the end.
    ///
    /// - Parameters:
    ///   - current: The current progress value.
    ///   - total: The total/maximum value. Values `<= 0` produce an all-unfilled bar.
    ///   - width: The visible character width of the bar. Values `<= 0` return an empty string.
    ///   - filledChar: The character used for the filled portion (default: `\u{2588}` full block).
    ///   - unfilledChar: The character used for the unfilled portion (default: `\u{2591}` light shade).
    ///   - filledColor: The foreground color for filled characters (default: green).
    ///   - unfilledColor: The foreground color for unfilled characters, or `nil` to use dim styling.
    /// - Returns: An ANSI-styled string whose visible length equals `width`, or an empty string if `width <= 0`.
    public static func render(
        current: Int,
        total: Int,
        width: Int,
        filledChar: Character = "\u{2588}",
        unfilledChar: Character = "\u{2591}",
        filledColor: Color = .ansi8(.green),
        unfilledColor: Color? = nil
    ) -> String {
        guard width > 0 else { return "" }

        let ratio = clampedRatio(current: current, total: total)
        let filledCount = Int((Double(width) * ratio).rounded())
        let unfilledCount = width - filledCount

        var result = ""

        // Filled portion
        if filledCount > 0 {
            result += foregroundEscape(for: filledColor)
            result += String(repeating: filledChar, count: filledCount)
        }

        // Unfilled portion
        if unfilledCount > 0 {
            if let color = unfilledColor {
                result += ANSICodes.reset
                result += foregroundEscape(for: color)
            } else {
                result += ANSICodes.reset
                result += ANSICodes.dim
            }
            result += String(repeating: unfilledChar, count: unfilledCount)
        }

        // Always reset at the end to prevent color bleed
        result += ANSICodes.reset

        return result
    }

    /// Renders an inline gauge bar with a centered percentage label overlaid on the bar.
    ///
    /// The percentage is calculated from `current / total`, clamped to 0-100%, and displayed
    /// as a string like `"50%"` centered over the gauge characters. The visible width of
    /// the returned string equals `width` exactly.
    ///
    /// - Parameters:
    ///   - current: The current progress value.
    ///   - total: The total/maximum value. Values `<= 0` produce a `"0%"` label.
    ///   - width: The visible character width of the bar. Values `<= 0` return an empty string.
    ///   - filledColor: The foreground color for filled characters (default: green).
    ///   - unfilledColor: The foreground color for unfilled characters, or `nil` to use dim styling.
    /// - Returns: An ANSI-styled string whose visible length equals `width`, or an empty string if `width <= 0`.
    public static func renderWithLabel(
        current: Int,
        total: Int,
        width: Int,
        filledColor: Color = .ansi8(.green),
        unfilledColor: Color? = nil
    ) -> String {
        guard width > 0 else { return "" }

        let ratio = clampedRatio(current: current, total: total)
        let percentage = Int((ratio * 100).rounded())
        let label = "\(percentage)%"
        let filledCount = Int((Double(width) * ratio).rounded())
        let unfilledCount = width - filledCount

        // Build the visible character array (filled + unfilled) with label overlay
        let filledChar: Character = "\u{2588}"
        let unfilledChar: Character = "\u{2591}"

        var chars: [Character] = []
        chars += Array(repeating: filledChar, count: filledCount)
        chars += Array(repeating: unfilledChar, count: unfilledCount)

        // Center the label over the bar
        let labelChars = Array(label)
        let labelStart = Swift.max((width - labelChars.count) / 2, 0)
        let labelEnd = Swift.min(labelStart + labelChars.count, width)
        for i in labelStart..<labelEnd {
            chars[i] = labelChars[i - labelStart]
        }

        // Render with style transitions only at the filled/unfilled boundary
        var result = ""

        if filledCount > 0 {
            result += foregroundEscape(for: filledColor)
            for i in 0..<filledCount {
                result.append(chars[i])
            }
        }

        if unfilledCount > 0 {
            result += ANSICodes.reset
            if let color = unfilledColor {
                result += foregroundEscape(for: color)
            } else {
                result += ANSICodes.dim
            }
            for i in filledCount..<width {
                result.append(chars[i])
            }
        }

        result += ANSICodes.reset
        return result
    }

    // MARK: - Private helpers

    /// Computes the fill ratio clamped to 0.0...1.0.
    /// Returns 0.0 when `total <= 0`.
    private static func clampedRatio(current: Int, total: Int) -> Double {
        let divisor = Double(total)
        guard divisor > 0 else { return 0.0 }
        let raw = Double(current) / divisor
        return Swift.min(Swift.max(raw, 0.0), 1.0)
    }

    /// Converts a ``Color`` value to the appropriate ANSI foreground escape string.
    private static func foregroundEscape(for color: Color) -> String {
        switch color {
        case .defaultColor:
            return "\u{001B}[39m"
        case .ansi8(let c):
            return ANSICodes.fg(c)
        case .ansi256(let idx):
            return ANSICodes.fg256(idx)
        case .truecolor(let r, let g, let b):
            return ANSICodes.fgRGB(r, g, b)
        }
    }
}
