// TerminalResolverTests.swift
// SwiftGUIKit
// Phase 0 — §1b terminal TokenResolver tests (RED first).

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("TerminalTokenResolver")
struct TerminalResolverTests {

    let resolver = TerminalTokenResolver(theme: .dark)

    // MARK: Color

    @Test("accent resolves to the theme tint on a truecolor terminal")
    func accentTruecolor() {
        let r = resolver.color(.accent, in: .terminalTruecolor)
        #expect(r.color == Theme.dark.primary)
        #expect(!r.attributes.contains(.bold))
        #expect(r.monoPrefix == nil)
    }

    @Test("accent falls back to bold on the mono floor")
    func accentMono() {
        let r = resolver.color(.accent, in: .terminalMono)
        #expect(r.color == .default)
        #expect(r.attributes.contains(.bold))
    }

    @Test("secondaryLabel is always dimmed")
    func secondaryLabelDim() {
        #expect(resolver.color(.secondaryLabel, in: .terminalTruecolor).attributes.contains(.dim))
        #expect(resolver.color(.secondaryLabel, in: .terminalMono).attributes.contains(.dim))
    }

    @Test("status colors carry a mono prefix so meaning is never color-only")
    func statusMonoPrefix() {
        // On the ASCII mono floor each status role carries its specific prefix.
        let expectedPrefix: [ColorRole: String] = [.destructive: "!", .success: "+", .warning: "*"]
        for (role, prefix) in expectedPrefix {
            let r = resolver.color(role, in: .terminalMono)
            #expect(r.monoPrefix == prefix, "\(role) must carry prefix \"\(prefix)\" on the mono floor")
        }
        // With color available, no prefix is needed.
        #expect(resolver.color(.warning, in: .terminalTruecolor).monoPrefix == nil)
    }

    // MARK: Type

    @Test("type roles map to weight/dim, not point size")
    func typeRoles() {
        #expect(resolver.font(.title, in: .terminalTruecolor).attributes.contains(.bold))
        #expect(resolver.font(.heading, in: .terminalTruecolor).attributes.contains(.bold))
        #expect(resolver.font(.body, in: .terminalTruecolor).attributes.isEmpty)
        #expect(resolver.font(.caption, in: .terminalTruecolor).attributes.contains(.dim))
    }

    // MARK: Spacing (2:1 aspect halving)

    @Test("horizontal spacing is the raw cell scale")
    func spacingHorizontal() {
        #expect(resolver.space(.m, axis: .horizontal, in: .terminalTruecolor) == .cells(2))
        #expect(resolver.space(.xl, axis: .horizontal, in: .terminalTruecolor) == .cells(4))
    }

    @Test("vertical spacing is halved (round up) for the 2:1 cell aspect")
    func spacingVerticalHalved() {
        #expect(resolver.space(.m, axis: .vertical, in: .terminalTruecolor) == .cells(1))
        #expect(resolver.space(.xl, axis: .vertical, in: .terminalTruecolor) == .cells(2))
        #expect(resolver.space(.s, axis: .vertical, in: .terminalTruecolor) == .cells(1)) // ceil(1/2)
    }

    // MARK: Glyph selection by font capability

    @Test("glyph picks unicode vs ascii from the context's capability")
    func glyphByCapability() {
        #expect(resolver.glyph(.check, in: .terminalTruecolor).text == "✓") // unicode
        #expect(resolver.glyph(.check, in: .terminalMono).text == "x")      // ascii floor
    }

    @Test("glyph honors a swapped-in SymbolSet")
    func glyphHonorsSymbolSet() {
        let custom = OverlaySymbolSet(base: DefaultSymbolSet(),
                                      overrides: [.check: GlyphMapping(sf: "x", unicode: "☑", ascii: "[x]")])
        let r = TerminalTokenResolver(theme: .dark, symbols: custom)
        #expect(r.glyph(.check, in: .terminalTruecolor).text == "☑")
    }

    // MARK: Motion & hit target

    @Test("reduceMotion collapses every motion role to zero")
    func reduceMotion() {
        var ctx = DesignContext.terminalTruecolor
        ctx.reduceMotion = true
        #expect(resolver.motion(.emphasized, in: ctx).durationMilliseconds == 0)
    }

    @Test("minimum hit target on a terminal is one cell")
    func hitTarget() {
        #expect(resolver.minHitTarget(in: .terminalTruecolor) == .cells(1))
    }

    @Test("touch pointer widens the hit target to two cells")
    func hitTargetTouch() {
        var ctx = DesignContext.terminalTruecolor
        ctx.pointer = .touch
        #expect(resolver.minHitTarget(in: ctx) == .cells(2))
    }

    // MARK: Density

    @Test("density adds breathing room above the compact floor")
    func densityAddsSpacing() {
        var regular = DesignContext.terminalTruecolor
        regular.density = .regular
        var spacious = DesignContext.terminalTruecolor
        spacious.density = .spacious
        // .m is 2 cells compact; +1 regular, +2 spacious (horizontal, unhalved).
        #expect(resolver.space(.m, axis: .horizontal, in: .terminalTruecolor) == .cells(2))
        #expect(resolver.space(.m, axis: .horizontal, in: regular) == .cells(3))
        #expect(resolver.space(.m, axis: .horizontal, in: spacious) == .cells(4))
        // Zero spacing (.xs) stays zero regardless of density.
        #expect(resolver.space(.xs, axis: .horizontal, in: spacious) == .cells(0))
    }

    // MARK: High contrast

    @Test("high contrast drops the dim attribute so nothing is de-emphasized by fading")
    func highContrastUndims() {
        var hc = DesignContext.terminalTruecolor
        hc.appearance = .highContrast
        #expect(resolver.color(.secondaryLabel, in: .terminalTruecolor).attributes.contains(.dim))
        #expect(!resolver.color(.secondaryLabel, in: hc).attributes.contains(.dim))
        #expect(!resolver.color(.separator, in: hc).attributes.contains(.dim))
    }
}
