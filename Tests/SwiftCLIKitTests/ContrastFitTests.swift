// ContrastFitTests.swift
// SwiftCLIKit

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ContrastFit")
struct ContrastFitTests {

    private func rgb(_ hex: String) -> TerminalRGB {
        TerminalRGB(hex: hex) ?? TerminalRGB(r: 0, g: 0, b: 0)
    }

    private let orange = "#FF9230"

    private func channelDistance(_ a: TerminalRGB, _ b: TerminalRGB) -> Int {
        max(abs(Int(a.r) - Int(b.r)), abs(Int(a.g) - Int(b.g)), abs(Int(a.b) - Int(b.b)))
    }

    @Test("accent already readable is returned unchanged", arguments: [
        "#000000", "#1E1E1E", "#002B36", "#0A0600",
    ])
    func unchangedOnDark(background: String) {
        let accent = rgb(orange)
        for target in [3.0, 4.5] {
            #expect(ContrastFit.fit(accent, against: rgb(background), target: target) == accent)
        }
    }

    @Test("proposal table: light backgrounds darken the accent", arguments: [
        ("#FFFFFF", 3.0, "#E27900"),
        ("#FFFFFF", 4.5, "#B56002"),
        ("#FDF6E3", 3.0, "#D77300"),
        ("#FDF6E3", 4.5, "#AD5B00"),
    ])
    func lightBackgrounds(background: String, target: Double, expectedHex: String) throws {
        let accent = rgb(orange)
        let bg = rgb(background)
        let fitted = try #require(ContrastFit.fit(accent, against: bg, target: target))
        #expect(ColorMath.contrastRatio(fitted, bg) >= target)
        #expect(channelDistance(fitted, rgb(expectedHex)) <= 2)
        #expect(ColorMath.relativeLuminance(fitted) < ColorMath.relativeLuminance(accent))
        // Hue preserved within a small tolerance.
        let before = ColorMath.oklch(accent)
        let after = ColorMath.oklch(fitted)
        #expect(abs(before.hue - after.hue) < 3.0)
        #expect(after.chroma >= 0.09)
    }

    @Test("mid grey has no hue-preserving fit at either target")
    func midGrey() {
        let grey = rgb("#808080")
        #expect(ContrastFit.fit(rgb(orange), against: grey, target: 3.0) == nil)
        #expect(ContrastFit.fit(rgb(orange), against: grey, target: 4.5) == nil)
    }

    @Test("the result is the nearest qualifying lightness")
    func nearest() throws {
        let accent = rgb(orange)
        let bg = rgb("#FFFFFF")
        let target = 4.5
        let fitted = try #require(ContrastFit.fit(accent, against: bg, target: target))
        let base = ColorMath.oklch(accent)
        let found = ColorMath.oklch(fitted)
        // Move one search step (0.01, twice the grid) back toward the accent: must fail the target
        // or the chroma floor.
        let nearer = found.lightness + 0.01
        let candidate = try #require(ColorMath.gamutFit(lightness: nearer, chroma: base.chroma, hue: base.hue))
        let qualifies = ColorMath.contrastRatio(candidate.color, bg) >= target && candidate.chroma >= 0.09
        #expect(!qualifies)
    }

    @Test("an accent equal to the background is deterministic and honest")
    func degenerate() {
        let accent = rgb(orange)
        let first = ContrastFit.fit(accent, against: accent, target: 3.0)
        let second = ContrastFit.fit(accent, against: accent, target: 3.0)
        #expect(first == second)
        if let fitted = first {
            #expect(ColorMath.contrastRatio(fitted, accent) >= 3.0)
        }
    }

    @Test("results are deterministic")
    func deterministic() {
        let results = (0..<5).map { _ in ContrastFit.fit(rgb(orange), against: rgb("#FDF6E3"), target: 3.0) }
        #expect(Set(results.map { $0 == nil ? "nil" : $0?.hex ?? "" }).count == 1)
    }

    @Test("a target at or below 1 returns the accent")
    func trivialTarget() {
        #expect(ContrastFit.fit(rgb(orange), against: rgb(orange), target: 1.0) == rgb(orange))
    }

    @Test("contrast ratio reference values")
    func contrastReference() {
        let black = rgb("#000000")
        let white = rgb("#FFFFFF")
        #expect(abs(ColorMath.contrastRatio(black, white) - 21.0) < 1e-9)
        #expect(abs(ColorMath.contrastRatio(white, white) - 1.0) < 1e-12)
        #expect(abs(ColorMath.contrastRatio(rgb(orange), black) - 9.4) < 0.05)
    }

    @Test("OKLCH of orange matches the reference")
    func oklchReference() {
        let lch = ColorMath.oklch(rgb(orange))
        #expect(abs(lch.lightness - 0.762) < 0.001)
        #expect(abs(lch.chroma - 0.167) < 0.001)
        #expect(abs(lch.hue - 57) < 1.0)
    }
}
