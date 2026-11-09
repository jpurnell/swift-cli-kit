// ColorMath.swift
// SwiftCLIKit

import Foundation

/// WCAG contrast and OKLab/OKLCH conversion, shared by ``ContrastFit`` and ``StatusCollision``.
enum ColorMath {

    struct OKLab: Equatable {
        let lightness: Double
        let a: Double
        let b: Double
    }

    struct OKLCH: Equatable {
        let lightness: Double
        let chroma: Double
        /// Degrees, 0..<360.
        let hue: Double
    }

    // MARK: sRGB transfer

    static func toLinear(_ channel: UInt8) -> Double {
        let c = Double(channel) / 255.0
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func toSRGBByte(_ linear: Double) -> UInt8 {
        if linear <= 0 { return 0 }
        if linear >= 1 { return 255 }
        // A NaN fails both comparisons above and is rejected here instead of being clamped.
        let encoded = linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1.0 / 2.4) - 0.055
        let scaled = (encoded * 255.0).rounded()
        guard scaled.isFinite, let byte = UInt8(exactly: scaled) else { return 0 }
        return byte
    }

    // MARK: WCAG

    static func relativeLuminance(_ color: TerminalRGB) -> Double {
        0.2126 * toLinear(color.r) + 0.7152 * toLinear(color.g) + 0.0722 * toLinear(color.b)
    }

    /// WCAG 2.x contrast ratio, 1...21, symmetric in its arguments.
    static func contrastRatio(_ a: TerminalRGB, _ b: TerminalRGB) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)   // denominator >= 0.05
    }

    // MARK: OKLab

    static func oklab(_ color: TerminalRGB) -> OKLab {
        let r = toLinear(color.r)
        let g = toLinear(color.g)
        let b = toLinear(color.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return OKLab(
            lightness: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    static func oklch(_ color: TerminalRGB) -> OKLCH {
        let lab = oklab(color)
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        var hue = atan2(lab.b, lab.a) * 180.0 / Double.pi
        hue = hue.truncatingRemainder(dividingBy: 360.0)
        if hue < 0 { hue += 360.0 }
        return OKLCH(lightness: lab.lightness, chroma: chroma, hue: hue)
    }

    /// Euclidean OKLab distance multiplied by 100.
    static func oklabDistance(_ x: TerminalRGB, _ y: TerminalRGB) -> Double {
        let p = oklab(x)
        let q = oklab(y)
        let dl = p.lightness - q.lightness
        let da = p.a - q.a
        let db = p.b - q.b
        return (dl * dl + da * da + db * db).squareRoot() * 100.0
    }

    // MARK: Gamut

    /// Chroma step used when pulling an out-of-gamut colour back inside sRGB.
    private static let chromaStep = 0.002
    /// Slack allowed outside 0...1 in linear light before a colour counts as out of gamut.
    private static let gamutTolerance = 0.0005

    /// Converts OKLCH to sRGB, reducing chroma in `chromaStep` decrements until the colour is
    /// inside the gamut (hue and lightness kept).
    /// - Returns: The colour and the chroma actually used, or `nil` if no chroma works.
    static func gamutFit(lightness: Double, chroma: Double, hue: Double) -> (color: TerminalRGB, chroma: Double)? {
        let radians = hue * Double.pi / 180.0
        let cosine = cos(radians)
        let sine = sin(radians)
        guard chroma.isFinite, chroma >= 0 else { return nil }
        guard let lastStep = Int(exactly: (chroma / chromaStep).rounded(.down)) else { return nil }
        for step in 0...lastStep {
            let c = chroma - Double(step) * chromaStep
            guard c >= 0 else { break }
            let a = c * cosine
            let b = c * sine
            let l = cube(lightness + 0.3963377774 * a + 0.2158037573 * b)
            let m = cube(lightness - 0.1055613458 * a - 0.0638541728 * b)
            let s = cube(lightness - 0.0894841775 * a - 1.2914855480 * b)
            let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
            let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
            let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
            let inGamut = [r, g, bl].allSatisfy { $0 >= -gamutTolerance && $0 <= 1.0 + gamutTolerance }
            if inGamut {
                let color = TerminalRGB(r: toSRGBByte(r), g: toSRGBByte(g), b: toSRGBByte(bl))
                return (color, c)
            }
        }
        return nil
    }

    private static func cube(_ x: Double) -> Double {
        x * x * x
    }
}
