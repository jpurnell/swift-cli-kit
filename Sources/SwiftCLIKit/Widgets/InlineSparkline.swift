// InlineSparkline.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-05-07.

import Foundation

/// A string-based inline sparkline that renders numeric data as a compact row of
/// Unicode block characters wrapped in ANSI color escapes.
///
/// Unlike the frame-based ``Sparkline`` widget, `InlineSparkline` produces a
/// self-contained `String` suitable for embedding inside status lines, log output,
/// or any context where a full ``Frame`` is not available.
///
/// ```swift
/// // CPU usage over the last 10 samples
/// let cpuHistory: [Double] = [12, 18, 25, 31, 44, 52, 61, 48, 37, 29]
///
/// let spark = InlineSparkline.render(
///     data: cpuHistory,
///     width: 20,
///     color: .ansi8(.green)
/// )
/// print("CPU: [\(spark)]")
/// // CPU: [    ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄]
/// ```
///
/// ## Block Characters
///
/// Each data point maps to one of nine levels:
///
/// | Index | Character | Description |
/// |-------|-----------|-------------|
/// | 0     | ` `       | Space (minimum) |
/// | 1     | `▁`       | U+2581 |
/// | 2     | `▂`       | U+2582 |
/// | 3     | `▃`       | U+2583 |
/// | 4     | `▄`       | U+2584 (mid-height) |
/// | 5     | `▅`       | U+2585 |
/// | 6     | `▆`       | U+2586 |
/// | 7     | `▇`       | U+2587 |
/// | 8     | `█`       | U+2588 (maximum) |
///
/// ## Normalization
///
/// Values are normalized to the visible data range (or explicit `min`/`max`)
/// and mapped to block indices 0-8. When all visible values are equal, the
/// mid-height block (index 4) is used.
public struct InlineSparkline: Sendable {

    /// The nine block characters from empty (space) to full block.
    private static let blocks: [Character] = [
        " ", "\u{2581}", "\u{2582}", "\u{2583}", "\u{2584}",
        "\u{2585}", "\u{2586}", "\u{2587}", "\u{2588}",
    ]

    /// Maximum block index (8).
    private static let maxBlockIndex = 8

    /// Mid-height block index used for equal-value data.
    private static let midBlockIndex = 4

    /// Renders a sparkline string from numeric data.
    ///
    /// - Parameters:
    ///   - data: The data points to visualize.
    ///   - width: The desired visible column width of the output.
    ///   - color: The foreground color for the sparkline (default: cyan).
    ///   - min: An explicit minimum for normalization. When `nil`, the data minimum is used.
    ///   - max: An explicit maximum for normalization. When `nil`, the data maximum is used.
    /// - Returns: An ANSI-colored string of Unicode block characters whose visible width
    ///   equals `width`. Returns an empty string when `width <= 0`.
    public static func render<T: BinaryFloatingPoint>(
        data: [T],
        width: Int,
        color: Color = .ansi8(.cyan),
        min: T? = nil,
        max: T? = nil
    ) -> String {
        guard width > 0 else { return "" }

        // Slice to the last `width` values (right-aligned).
        let visibleData: [T]
        if data.count > width {
            visibleData = Array(data.suffix(width))
        } else {
            visibleData = data
        }

        // Build the block characters for each visible data point.
        let blockChars: [Character]
        if visibleData.isEmpty {
            blockChars = []
        } else {
            blockChars = mapToBlocks(visibleData, explicitMin: min, explicitMax: max)
        }

        // Left-pad with spaces if data is shorter than width.
        let padCount = width - blockChars.count
        var body = ""
        if padCount > 0 {
            body += String(repeating: " ", count: padCount)
        }
        for ch in blockChars {
            body.append(ch)
        }

        // Wrap in color escapes.
        let colorEscape = foregroundEscape(for: color)
        return colorEscape + body + ANSICodes.reset
    }

    // MARK: - Private Helpers

    /// Maps an array of values to block characters using min/max normalization.
    ///
    /// - Parameters:
    ///   - values: Non-empty array of data points.
    ///   - explicitMin: Optional override for the range minimum.
    ///   - explicitMax: Optional override for the range maximum.
    /// - Returns: An array of block characters, one per value.
    private static func mapToBlocks<T: BinaryFloatingPoint>(
        _ values: [T],
        explicitMin: T?,
        explicitMax: T?
    ) -> [Character] {
        let lo = explicitMin ?? (values.min() ?? T.zero)
        let hi = explicitMax ?? (values.max() ?? T.zero)
        let range = hi - lo

        // All equal -> mid-height blocks
        guard range > T.zero else {
            return values.map { _ in blocks[midBlockIndex] }
        }

        return values.map { value in
            let clamped = Swift.min(Swift.max(value, lo), hi)
            let normalized = Double((clamped - lo) / range)
            let index = Int((normalized * Double(maxBlockIndex)).rounded(.down))
            let safeIndex = Swift.min(Swift.max(index, 0), maxBlockIndex)
            return blocks[safeIndex]
        }
    }

    /// Produces a foreground ANSI escape string for the given ``Color``,
    /// emitting at the highest fidelity the color variant specifies.
    ///
    /// - Parameter color: The color to convert.
    /// - Returns: An ANSI SGR escape string, or empty for ``Color/defaultColor``.
    private static func foregroundEscape(for color: Color) -> String {
        switch color {
        case .defaultColor:
            return "\u{001B}[39m"
        case .ansi8(let ansiColor):
            return ANSICodes.fg(ansiColor)
        case .ansi256(let index):
            return ANSICodes.fg256(index)
        case .truecolor(let r, let g, let b):
            return ANSICodes.fgRGB(r, g, b)
        }
    }
}
