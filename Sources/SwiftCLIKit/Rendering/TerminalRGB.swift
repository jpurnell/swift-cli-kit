// TerminalRGB.swift
// SwiftCLIKit

import Foundation

/// An opaque 8-bit-per-channel sRGB colour, as a terminal reports or accepts it.
///
/// Unlike ``Color`` this has no "default" or palette cases: it is always a concrete colour,
/// which is what contrast and distance calculations need.
public struct TerminalRGB: Sendable, Equatable, Hashable {
    /// Red, 0...255.
    public let r: UInt8
    /// Green, 0...255.
    public let g: UInt8
    /// Blue, 0...255.
    public let b: UInt8

    /// Creates a colour from 8-bit channels.
    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Creates a colour from `"#RRGGBB"`, `"RRGGBB"` or `"#RGB"`, using the same parser as ``Color/fromHex(_:)``.
    /// - Returns: `nil` if the string is malformed.
    public init?(hex: String) {
        guard let color = Color.fromHex(hex),
              case let .truecolor(r, g, b) = color else { return nil }
        self.init(r: r, g: g, b: b)
    }

    /// The colour as an uppercase `"#RRGGBB"` string.
    public var hex: String {
        func pair(_ value: UInt8) -> String {
            let digits = String(value, radix: 16, uppercase: true)
            return digits.count == 1 ? "0\(digits)" : digits
        }
        return "#\(pair(r))\(pair(g))\(pair(b))"
    }

    /// This colour as a truecolor ``Color``.
    public var color: Color {
        .truecolor(r: r, g: g, b: b)
    }
}
