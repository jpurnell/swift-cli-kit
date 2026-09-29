// ASCIIArt.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Renders pixel data as terminal cells using Unicode half-block characters.
///
/// Each terminal cell represents two vertical pixels: the upper half-block (U+2580)
/// uses the foreground color for the top pixel and the background color for the
/// bottom pixel. This achieves 2x vertical resolution.
///
/// ```swift
/// let rgbaBytes = [UInt8](repeating: 0, count: 4 * 100 * 50)  // RGBA, 4 per pixel
/// // PixelData validates the byte count, so the initializer is failable.
/// if let pixels = PixelData(bytes: rgbaBytes, width: 100, height: 50) {
///     let cells = ASCIIArt.render(pixels: pixels, width: 50, height: 25)
///     _ = cells
/// }
/// // cells is a 25-row, 50-column grid of styled Cell values
/// ```
public struct ASCIIArt: Sendable {

    /// The upper half-block character used for dual-color cell rendering.
    private static let upperHalfBlock: Character = "\u{2580}"

    /// Render pixel data to a 2D grid of styled terminal cells.
    ///
    /// Each cell represents two vertical pixels: foreground color for top pixel,
    /// background color for bottom pixel, displayed as an upper half-block.
    /// - Parameters:
    ///   - pixels: Source RGBA pixel data.
    ///   - targetWidth: Target width in terminal cells.
    ///   - targetHeight: Target height in terminal cells (each cell = 2 pixel rows).
    /// - Returns: 2D array of ``Cell`` values (height rows, width columns).
    public static func render(
        pixels: PixelData,
        width targetWidth: Int,
        height targetHeight: Int
    ) -> [[Cell]] {
        guard targetWidth > 0, targetHeight > 0 else { return [] }
        guard pixels.width > 0, pixels.height > 0 else { return [] }

        // Scale to target pixel dimensions (width x height*2 since each cell = 2 rows)
        let scaled = scale(pixels: pixels,
                          targetWidth: targetWidth,
                          targetHeight: targetHeight * 2)

        var rows: [[Cell]] = []
        rows.reserveCapacity(targetHeight)

        for cellRow in 0..<targetHeight {
            var row: [Cell] = []
            row.reserveCapacity(targetWidth)

            let topY = cellRow * 2
            let bottomY = topY + 1

            for x in 0..<targetWidth {
                guard let top = scaled.pixel(x: x, y: topY) else {
                    row.append(Cell(character: " "))
                    continue
                }
                let bottom: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)
                if let b = scaled.pixel(x: x, y: bottomY) {
                    bottom = b
                } else {
                    bottom = (r: 0, g: 0, b: 0, a: 0)
                }

                let topTransparent = top.a < 128
                let bottomTransparent = bottom.a < 128

                if topTransparent && bottomTransparent {
                    row.append(Cell(character: " "))
                } else if topTransparent {
                    // Only bottom pixel visible: lower half-block with bg color
                    row.append(Cell(
                        character: "\u{2584}",
                        fg: .truecolor(r: bottom.r, g: bottom.g, b: bottom.b)
                    ))
                } else if bottomTransparent {
                    // Only top pixel visible: upper half-block with fg color
                    row.append(Cell(
                        character: upperHalfBlock,
                        fg: .truecolor(r: top.r, g: top.g, b: top.b)
                    ))
                } else {
                    // Both pixels visible: upper half-block, fg=top, bg=bottom
                    row.append(Cell(
                        character: upperHalfBlock,
                        fg: .truecolor(r: top.r, g: top.g, b: top.b),
                        bg: .truecolor(r: bottom.r, g: bottom.g, b: bottom.b)
                    ))
                }
            }

            rows.append(row)
        }

        return rows
    }

    /// Scale pixel data to target dimensions using nearest-neighbor sampling.
    ///
    /// Target pixel dimensions are `targetWidth` x `targetHeight`.
    /// - Parameters:
    ///   - pixels: Source pixel data.
    ///   - targetWidth: Desired width in pixels.
    ///   - targetHeight: Desired height in pixels.
    /// - Returns: Scaled ``PixelData``.
    public static func scale(
        pixels: PixelData,
        targetWidth: Int,
        targetHeight: Int
    ) -> PixelData {
        guard targetWidth > 0, targetHeight > 0 else {
            return .empty
        }
        guard pixels.width > 0, pixels.height > 0 else {
            return .empty
        }

        var result = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)

        for y in 0..<targetHeight {
            let srcY = y * pixels.height / targetHeight
            for x in 0..<targetWidth {
                let srcX = x * pixels.width / targetWidth
                let srcOffset = (srcY * pixels.width + srcX) * 4
                let dstOffset = (y * targetWidth + x) * 4
                result[dstOffset] = pixels.bytes[srcOffset]
                result[dstOffset + 1] = pixels.bytes[srcOffset + 1]
                result[dstOffset + 2] = pixels.bytes[srcOffset + 2]
                result[dstOffset + 3] = pixels.bytes[srcOffset + 3]
            }
        }

        return PixelData(bytes: result, width: targetWidth, height: targetHeight) ?? .empty
    }

    /// Convert an RGB color to the nearest ANSI 256-color index.
    /// - Parameters:
    ///   - r: Red component (0-255).
    ///   - g: Green component (0-255).
    ///   - b: Blue component (0-255).
    /// - Returns: The nearest xterm-256 palette index.
    public static func nearestANSI256(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
        // Use the Color type's downsampling for consistency
        let color = Color.truecolor(r: r, g: g, b: b)
        let downsampled = color.downsampled(to: .extended)
        switch downsampled {
        case .ansi256(let idx):
            return idx
        default:
            return 0
        }
    }
}
