// HexColor.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Converts CSS-style hex color strings (e.g. `"#FF8800"`) to the nearest ANSI 8-color value.
public enum HexColor: Sendable {

    // MARK: - Hex to ANSI-8

    /// Maps a 6-digit hex color string to the closest ``ANSIColor`` using HSV hue buckets.
    /// - Parameter hex: A hex string like `"FF8800"` or `"#FF8800"`.
    /// - Returns: The nearest ANSI color, or `nil` if the string is malformed.
    public static func toANSI8(_ hex: String) -> ANSIColor? {
        var cleaned = hex
        if cleaned.hasPrefix("#") {
            cleaned = String(cleaned.dropFirst())
        }

        guard cleaned.count == 6 else { return nil }
        guard let value = UInt32(cleaned, radix: 16) else { return nil }

        // Channels stay integral: they are bytes, and `max`/`min` return one of their
        // arguments unchanged, so `maxC == r` below is an exact comparison of exact values
        // rather than a float-equality question that had no business being asked.
        let r = Int((value >> 16) & 0xFF)
        let g = Int((value >> 8) & 0xFF)
        let b = Int(value & 0xFF)

        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        let brightness = Double(maxC) / 255.0
        let saturation: Double
        guard maxC > 0 else {
            saturation = 0
            return brightness > 0.5 ? .white : .black
        }
        saturation = Double(delta) / Double(maxC)

        // Achromatic: low saturation → black or white based on brightness
        guard saturation > 0.15 else {
            return brightness > 0.5 ? .white : .black
        }

        // Compute hue in degrees (0-360); delta > 0 guaranteed by saturation > 0.15 guard above
        guard delta > 0 else { return brightness > 0.5 ? .white : .black }
        let hue: Double
        if maxC == r {
            hue = 60.0 * ((Double(g - b) / Double(delta)).truncatingRemainder(dividingBy: 6))
        } else if maxC == g {
            hue = 60.0 * ((Double(b - r) / Double(delta)) + 2)
        } else {
            hue = 60.0 * ((Double(r - g) / Double(delta)) + 4)
        }
        let normalizedHue = hue < 0 ? hue + 360 : hue

        // Map hue ranges to ANSI colors
        // Red:     330-360, 0-15
        // Yellow:  15-75
        // Green:   75-165
        // Cyan:    165-195
        // Blue:    195-285
        // Magenta: 285-330
        switch normalizedHue {
        case 0..<15, 330..<360:
            return .red
        case 15..<75:
            return .yellow
        case 75..<165:
            return .green
        case 165..<195:
            return .cyan
        case 195..<285:
            return .blue
        case 285..<330:
            return .magenta
        default:
            return .red
        }
    }

    // MARK: - v0.2.0 additions

    /// Converts a hex color string to a ``Color`` value.
    /// - Parameter hex: A hex string like `"FF8800"` or `"#FF8800"`.
    /// - Returns: A ``Color``, or `nil` if the string is malformed.
    public static func toColor(_ hex: String) -> Color? {
        Color.fromHex(hex)
    }

    /// Converts a hex color string to an ANSI escape sequence at the given capability.
    /// - Parameters:
    ///   - hex: A hex string like `"FF8800"` or `"#FF8800"`.
    ///   - capability: The terminal's color capability.
    /// - Returns: An escape string, or empty if invalid.
    public static func toEscape(_ hex: String, capability: ColorCapability) -> String {
        guard let color = Color.fromHex(hex) else { return "" }
        return ColorNegotiation.fgEscape(color, capability: capability)
    }

    // MARK: - Hex to ANSI escape string

    /// Converts a hex color string directly to an ANSI foreground escape sequence.
    /// - Parameter hex: A hex string like `"FF8800"` or `"#FF8800"`.
    /// - Returns: The ANSI foreground escape string, or an empty string if the hex is invalid.
    public static func toANSIEscape(_ hex: String) -> String {
        guard let color = toANSI8(hex) else { return "" }
        return ANSICodes.fg(color)
    }
}
