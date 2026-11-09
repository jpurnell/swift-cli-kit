// ContrastFit.swift
// SwiftCLIKit

import Foundation

/// Adjusts an accent colour so it can be read against a terminal background.
public enum ContrastFit {

    /// Lightness resolution of the search (OKLab L units).
    private static let lightnessStep = 0.005
    /// Number of steps covering the full 0...1 lightness span.
    private static let stepCount = 200
    /// Lowest and highest OKLab lightness considered.
    private static let lightnessRange = 0.05...0.99
    /// Chroma below this is treated as having lost the accent's identity.
    private static let minimumChroma = 0.09

    /// Finds the accent's nearest-lightness variant that meets a WCAG contrast target.
    ///
    /// The accent's OKLCH hue and chroma are kept; only lightness moves, searched both lighter
    /// and darker in steps of 0.005 from the accent's own lightness (lighter wins a tie). Colours
    /// outside the sRGB gamut have their chroma reduced, and a candidate whose chroma falls below
    /// 0.09 does not qualify.
    ///
    /// - Parameters:
    ///   - accent: The colour to fit.
    ///   - background: The terminal background it will be drawn on.
    ///   - target: Required WCAG contrast ratio, such as 3.0 or 4.5.
    /// - Returns: `accent` unchanged if it already meets `target`; the fitted colour otherwise;
    ///   `nil` if no hue-preserving colour qualifies.
    public static func fit(_ accent: TerminalRGB, against background: TerminalRGB, target: Double) -> TerminalRGB? {
        if ColorMath.contrastRatio(accent, background) >= target { return accent }

        let origin = ColorMath.oklch(accent)
        for index in 0...stepCount {
            let distance = Double(index) * lightnessStep
            for direction in [1.0, -1.0] {
                let lightness = origin.lightness + direction * distance
                if let found = qualifying(lightness: lightness, origin: origin, background: background, target: target) {
                    return found
                }
            }
        }
        return nil
    }

    private static func qualifying(
        lightness: Double,
        origin: ColorMath.OKLCH,
        background: TerminalRGB,
        target: Double
    ) -> TerminalRGB? {
        guard lightnessRange.contains(lightness) else { return nil }
        guard let candidate = ColorMath.gamutFit(lightness: lightness, chroma: origin.chroma, hue: origin.hue),
              candidate.chroma >= minimumChroma else { return nil }
        return ColorMath.contrastRatio(candidate.color, background) >= target ? candidate.color : nil
    }
}
