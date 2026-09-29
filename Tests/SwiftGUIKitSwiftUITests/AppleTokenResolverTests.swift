// AppleTokenResolverTests.swift
// SwiftGUIKitSwiftUI
// Phase 2 P2.0 — the Apple resolver defers to the system, so these mappings are
// the concrete, verifiable form of "HIG is the baseline".

#if canImport(SwiftUI)
import Testing
import SwiftUI
import SwiftGUIKit
@testable import SwiftGUIKitSwiftUI

@Suite("AppleTokenResolver (HIG by deference)")
struct AppleTokenResolverTests {

    let resolver = AppleTokenResolver()

    @Test("content colors defer to the system semantic colors")
    func contentColors() {
        #expect(resolver.color(.label) == .primary)
        #expect(resolver.color(.secondaryLabel) == .secondary)
        #expect(resolver.color(.accent) == .accentColor)
    }

    @Test("status colors defer to the standard system colors")
    func statusColors() {
        #expect(resolver.color(.destructive) == .red)
        #expect(resolver.color(.success) == .green)
        #expect(resolver.color(.warning) == .yellow)
    }

    @Test("type roles map to Dynamic Type text styles")
    func typeRoles() {
        #expect(resolver.font(.title) == .largeTitle)
        #expect(resolver.font(.heading) == .headline)
        #expect(resolver.font(.body) == .body)
        #expect(resolver.font(.caption) == .caption)
    }

    @Test("symbols resolve to SF Symbol names (the sf field pays off)")
    func symbols() {
        #expect(resolver.symbolName(.check) == "checkmark")
        #expect(resolver.symbolName(.search) == "magnifyingglass")
        #expect(resolver.symbolName(.disclosureCollapsed) == "chevron.right")
    }

    @Test("a swapped-in SymbolSet changes the resolved SF name")
    func pluggableSymbols() {
        let custom = OverlaySymbolSet(base: DefaultSymbolSet(),
                                      overrides: [.check: GlyphMapping(sf: "checkmark.seal", unicode: "✓", ascii: "x")])
        #expect(AppleTokenResolver(symbols: custom).symbolName(.check) == "checkmark.seal")
    }

    @Test("default metrics: 8pt-rhythm spacing, 28pt mouse hit target")
    func metrics() {
        // Default context is desktop (regular density, mouse pointer).
        #expect(resolver.spacing(.m) == 16)
        #expect(resolver.spacing(.xs) == 4)
        #expect(resolver.minHitTarget == 28)
    }

    @Test("density scales the spacing rhythm")
    func densityScalesSpacing() {
        let compact = AppleTokenResolver(context: DesignContext(density: .compact, surface: .swiftUI))
        let spacious = AppleTokenResolver(context: DesignContext(density: .spacious, surface: .swiftUI))
        #expect(compact.spacing(.m) == 12)    // 16 × 0.75
        #expect(spacious.spacing(.m) == 24)   // 16 × 1.5
    }

    @Test("pointer sets the hit target: touch restores the 44pt HIG floor")
    func pointerSetsHitTarget() {
        let touch = AppleTokenResolver(context: DesignContext(pointer: .touch, surface: .swiftUI))
        let keyboard = AppleTokenResolver(context: DesignContext(pointer: .none, surface: .swiftUI))
        #expect(touch.minHitTarget == 44)
        #expect(keyboard.minHitTarget == 44)
    }
}
#endif
