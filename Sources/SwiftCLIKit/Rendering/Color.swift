// Color.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// The level of color support available in the current terminal.
public enum ColorCapability: Int, Sendable, Comparable {
    /// No color support.
    case none = 0
    /// Basic 8/16 ANSI colors (SGR 30-37 / 90-97).
    case basic
    /// Extended 256-color palette (SGR 38;5;n).
    case extended
    /// Full 24-bit RGB truecolor (SGR 38;2;r;g;b).
    case truecolor

    /// Returns whether the left-hand capability is strictly less capable than the right-hand one.
    public static func < (lhs: ColorCapability, rhs: ColorCapability) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A terminal color at any fidelity level.
///
/// `Color` unifies ANSI-8, xterm-256, and 24-bit RGB under a single type.
/// Use ``fromHex(_:)`` to parse CSS hex strings and ``downsampled(to:)`` to
/// adapt colors to the current terminal capability.
///
/// ```swift
/// // Parse a hex color and downsample for a 256-color terminal
/// if let orange = Color.fromHex("#FF8800") {
///     let safe = orange.downsampled(to: .extended)
///     // safe is .ansi256(208) — the nearest palette entry
/// }
///
/// // Direct construction
/// let red = Color.ansi8(.red)
/// let teal = Color.ansi256(30)
/// let exact = Color.truecolor(r: 100, g: 149, b: 237)
/// ```
public enum Color: Sendable, Equatable, Hashable {
    /// The terminal's default color — no explicit SGR code emitted.
    /// Uses SGR 39 (default fg) or SGR 49 (default bg).
    case defaultColor

    /// One of the 8/16 standard ANSI colors.
    case ansi8(ANSIColor)
    /// A color from the 256-color palette (0-255).
    case ansi256(UInt8)
    /// A 24-bit RGB color.
    case truecolor(r: UInt8, g: UInt8, b: UInt8)

    /// The terminal's default foreground/background color.
    public static let `default`: Color = .defaultColor

    // MARK: - xterm-256 palette

    /// The full xterm-256 color palette as RGB tuples.
    private static let xterm256Palette: [(UInt8, UInt8, UInt8)] = {
        var palette = [(UInt8, UInt8, UInt8)]()
        palette.reserveCapacity(256)

        // 0-7: Standard ANSI colors
        let standardColors: [(UInt8, UInt8, UInt8)] = [
            (0, 0, 0),         // 0  black
            (128, 0, 0),       // 1  red
            (0, 128, 0),       // 2  green
            (128, 128, 0),     // 3  yellow
            (0, 0, 128),       // 4  blue
            (128, 0, 128),     // 5  magenta
            (0, 128, 128),     // 6  cyan
            (192, 192, 192),   // 7  white
        ]
        palette.append(contentsOf: standardColors)

        // 8-15: Bright ANSI colors
        let brightColors: [(UInt8, UInt8, UInt8)] = [
            (128, 128, 128),   // 8  bright black (gray)
            (255, 0, 0),       // 9  bright red
            (0, 255, 0),       // 10 bright green
            (255, 255, 0),     // 11 bright yellow
            (0, 0, 255),       // 12 bright blue
            (255, 0, 255),     // 13 bright magenta
            (0, 255, 255),     // 14 bright cyan
            (255, 255, 255),   // 15 bright white
        ]
        palette.append(contentsOf: brightColors)

        // 16-231: 6x6x6 color cube
        for i in 0..<216 {
            let rIdx = i / 36
            let gIdx = (i % 36) / 6
            let bIdx = i % 6
            let r = UInt8(rIdx == 0 ? 0 : 55 + 40 * rIdx)
            let g = UInt8(gIdx == 0 ? 0 : 55 + 40 * gIdx)
            let b = UInt8(bIdx == 0 ? 0 : 55 + 40 * bIdx)
            palette.append((r, g, b))
        }

        // 232-255: Grayscale ramp
        for i in 0..<24 {
            let v = UInt8(8 + 10 * i)
            palette.append((v, v, v))
        }

        return palette
    }()

    /// Parses a CSS-style hex string into a truecolor value.
    /// - Parameter hex: A hex string like `"FF8800"`, `"#FF8800"`, or `"#F80"`.
    /// - Returns: A `.truecolor` value, or `nil` if the string is malformed.
    public static func fromHex(_ hex: String) -> Color? {
        var cleaned = hex
        if cleaned.hasPrefix("#") {
            cleaned = String(cleaned.dropFirst())
        }

        // Expand 3-digit shorthand: "F80" → "FF8800"
        if cleaned.count == 3 {
            let expanded = cleaned.map { "\($0)\($0)" }.joined()
            cleaned = expanded
        }

        guard cleaned.count == 6 else { return nil }
        guard let value = UInt32(cleaned, radix: 16) else { return nil }

        let r = UInt8((value >> 16) & 0xFF)
        let g = UInt8((value >> 8) & 0xFF)
        let b = UInt8(value & 0xFF)

        return .truecolor(r: r, g: g, b: b)
    }

    /// Reduces this color to fit within the given capability level.
    /// - Parameter capability: The maximum color fidelity to target.
    /// - Returns: A color representable at the given capability.
    public func downsampled(to capability: ColorCapability) -> Color {
        switch capability {
        case .truecolor:
            return self

        case .extended:
            switch self {
            case .defaultColor:
                return self
            case .truecolor(let r, let g, let b):
                let index = Color.nearestXterm256(r: r, g: g, b: b)
                return .ansi256(index)
            case .ansi256, .ansi8:
                return self
            }

        case .basic:
            switch self {
            case .defaultColor:
                return self
            case .truecolor(let r, let g, let b):
                let hex = Color.rgbToHex(r: r, g: g, b: b)
                guard let ansi = HexColor.toANSI8(hex) else {
                    return .ansi8(.white)
                }
                return .ansi8(ansi)
            case .ansi256(let idx):
                let (r, g, b) = Color.xterm256Palette[Int(idx)]
                let hex = Color.rgbToHex(r: r, g: g, b: b)
                guard let ansi = HexColor.toANSI8(hex) else {
                    return .ansi8(.white)
                }
                return .ansi8(ansi)
            case .ansi8:
                return self
            }

        case .none:
            return .ansi8(.black)
        }
    }

    // MARK: - Private helpers

    /// Finds the nearest xterm-256 palette index to the given RGB color.
    private static func nearestXterm256(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
        let ri = Int(r)
        let gi = Int(g)
        let bi = Int(b)

        var bestIndex = 0
        var bestDist = Int.max

        // Optimization: check grayscale ramp first if color is near-gray
        let maxC = max(ri, gi, bi)
        let minC = min(ri, gi, bi)
        if maxC - minC < 20 {
            for i in 232...255 {
                let (pr, pg, pb) = xterm256Palette[i]
                let dist = distanceSquared(ri, gi, bi, Int(pr), Int(pg), Int(pb))
                if dist < bestDist {
                    bestDist = dist
                    bestIndex = i
                }
            }
        }

        // Check color cube (16-231)
        for i in 16...231 {
            let (pr, pg, pb) = xterm256Palette[i]
            let dist = distanceSquared(ri, gi, bi, Int(pr), Int(pg), Int(pb))
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        // Also check the 16 standard/bright colors (0-15)
        for i in 0...15 {
            let (pr, pg, pb) = xterm256Palette[i]
            let dist = distanceSquared(ri, gi, bi, Int(pr), Int(pg), Int(pb))
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        return UInt8(bestIndex)
    }

    /// Finds the nearest ANSI 8/16 color to the given RGB color.
    static func nearestANSI8(r: UInt8, g: UInt8, b: UInt8) -> ANSIColor { // LIVE: library API for consumers
        let ri = Int(r)
        let gi = Int(g)
        let bi = Int(b)

        var bestColor = ANSIColor.black
        var bestDist = Int.max

        for ansiColor in ANSIColor.allCases {
            let (pr, pg, pb) = xterm256Palette[Int(ansiColor.rawValue)]
            let dist = distanceSquared(ri, gi, bi, Int(pr), Int(pg), Int(pb))
            if dist < bestDist {
                bestDist = dist
                bestColor = ansiColor
            }
        }

        return bestColor
    }

    /// Converts RGB components to a 6-digit uppercase hex string.
    private static func rgbToHex(r: UInt8, g: UInt8, b: UInt8) -> String {
        let hexChars: [Character] = Array("0123456789ABCDEF")
        return String([
            hexChars[Int(r >> 4)], hexChars[Int(r & 0x0F)],
            hexChars[Int(g >> 4)], hexChars[Int(g & 0x0F)],
            hexChars[Int(b >> 4)], hexChars[Int(b & 0x0F)],
        ])
    }

    /// Euclidean distance squared between two RGB colors.
    private static func distanceSquared(
        _ r1: Int, _ g1: Int, _ b1: Int,
        _ r2: Int, _ g2: Int, _ b2: Int
    ) -> Int {
        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2
        return dr * dr + dg * dg + db * db
    }
}
