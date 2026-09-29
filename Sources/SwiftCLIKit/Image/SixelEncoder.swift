// SixelEncoder.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Encodes pixel data into Sixel graphics format.
///
/// Sixel operates on raw RGBA pixels (not compressed image files) and produces
/// DCS escape sequences. Each sixel band is 6 pixels tall; pixel rows are
/// grouped into bands and encoded per palette color.
///
/// ```swift
/// let rgbaBytes = [UInt8](repeating: 0, count: 4 * 80 * 24)  // RGBA, 4 per pixel
/// // PixelData validates the byte count, so the initializer is failable.
/// if let pixels = PixelData(bytes: rgbaBytes, width: 80, height: 24) {
///     let sequence = SixelEncoder.encode(pixels: pixels, maxColors: 16)
///     print(sequence) // writes sixel image to compatible terminal
/// }
/// ```
public struct SixelEncoder: Sendable {

    /// Encode pixel data into Sixel format.
    /// - Parameters:
    ///   - pixels: RGBA pixel data.
    ///   - maxColors: Maximum palette size (default 256).
    /// - Returns: DCS escape sequence string.
    public static func encode(
        pixels: PixelData,
        maxColors: Int = 256
    ) -> String {
        guard pixels.width > 0, pixels.height > 0 else { return "" }
        guard maxColors > 0 else { return "" }

        let (indices, palette) = quantize(pixels: pixels, maxColors: maxColors)

        // DCS introducer: ESC P q
        var result = "\u{1B}Pq"

        // Define palette: #index;2;r%;g%;b%  (percentages 0-100)
        for (index, color) in palette.enumerated() {
            let rPct = Int(color.r) * 100 / 255
            let gPct = Int(color.g) * 100 / 255
            let bPct = Int(color.b) * 100 / 255
            result += "#\(index);2;\(rPct);\(gPct);\(bPct)"
        }

        // Encode sixel bands (each band = 6 pixel rows)
        let bandCount = (pixels.height + 5) / 6

        for band in 0..<bandCount {
            if band > 0 {
                result += "-"  // newline between bands
            }

            for colorIndex in 0..<palette.count {
                var bandData = ""

                for x in 0..<pixels.width {
                    var sixelBits: UInt8 = 0

                    for row in 0..<6 {
                        let y = band * 6 + row
                        guard y < pixels.height else { continue }

                        let pixelIndex = y * pixels.width + x
                        if indices[pixelIndex] == UInt8(colorIndex) {
                            sixelBits |= 1 << row
                        }
                    }

                    // Sixel character = bits + 63
                    bandData += String(UnicodeScalar(sixelBits + 63))
                }

                // Only emit color data if it has non-empty content
                let hasContent = bandData.contains(where: { $0 != Character(UnicodeScalar(63)) })
                if hasContent {
                    result += "#\(colorIndex)\(bandData)"
                }
            }
        }

        // String Terminator: ESC backslash
        result += "\u{1B}\\"

        return result
    }

    /// Simple color quantization using nearest-color matching.
    ///
    /// Builds a palette from the unique colors in the image (up to maxColors),
    /// then maps each pixel to the nearest palette entry.
    /// - Parameters:
    ///   - pixels: RGBA pixel data.
    ///   - maxColors: Maximum number of palette entries.
    /// - Returns: A tuple of per-pixel palette indices and the palette itself.
    public static func quantize(
        pixels: PixelData,
        maxColors: Int
    ) -> (indices: [UInt8], palette: [(r: UInt8, g: UInt8, b: UInt8)]) {
        guard maxColors > 0 else { return ([], []) }

        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        var colorMap: [UInt32: UInt8] = [:]

        let pixelCount = pixels.width * pixels.height
        var indices = [UInt8](repeating: 0, count: pixelCount)

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = pixels.bytes[offset]
            let g = pixels.bytes[offset + 1]
            let b = pixels.bytes[offset + 2]

            let key = (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)

            if let existing = colorMap[key] {
                indices[i] = existing
            } else if palette.count < maxColors {
                let idx = UInt8(palette.count)
                palette.append((r: r, g: g, b: b))
                colorMap[key] = idx
                indices[i] = idx
            } else {
                // Find nearest palette color
                var bestIdx: UInt8 = 0
                var bestDist = Int.max
                for (pIdx, pColor) in palette.enumerated() {
                    let dr = Int(r) - Int(pColor.r)
                    let dg = Int(g) - Int(pColor.g)
                    let db = Int(b) - Int(pColor.b)
                    let dist = dr * dr + dg * dg + db * db
                    if dist < bestDist {
                        bestDist = dist
                        bestIdx = UInt8(pIdx)
                    }
                }
                indices[i] = bestIdx
            }
        }

        return (indices, palette)
    }
}
