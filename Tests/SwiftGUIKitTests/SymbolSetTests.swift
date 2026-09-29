// SymbolSetTests.swift
// SwiftGUIKit
// Phase 0 — §1a token/symbol layer tests (RED first).

import Testing
@testable import SwiftGUIKit

@Suite("SymbolSet")
struct SymbolSetTests {

    /// A `Sendable`-bounded sink: compiles only if the argument is `Sendable`.
    private func requireSendable<T: Sendable>(_ value: T) {}

    @Test("DefaultSymbolSet is a total function over every Symbol case")
    func defaultSetIsTotal() {
        let set = DefaultSymbolSet()
        // CaseIterable guarantees we cover the whole closed enum.
        for symbol in Symbol.allCases {
            let mapping = set.mapping(for: symbol)
            #expect(!mapping.sf.isEmpty, "SF name missing for \(symbol)")
            #expect(!mapping.unicode.isEmpty, "unicode glyph missing for \(symbol)")
            #expect(!mapping.ascii.isEmpty, "ascii floor missing for \(symbol)")
        }
    }

    @Test("DefaultSymbolSet maps known symbols to their baseline glyphs")
    func defaultSetKnownMappings() {
        let set = DefaultSymbolSet()
        #expect(set.mapping(for: .check).unicode == "✓")
        #expect(set.mapping(for: .check).ascii == "x")
        #expect(set.mapping(for: .search).sf == "magnifyingglass")
        #expect(set.mapping(for: .disclosureCollapsed).unicode == "▸")
    }

    @Test("OverlaySymbolSet returns the override where present, base otherwise")
    func overlayOverridesSelectively() {
        let base = DefaultSymbolSet()
        let customCheck = GlyphMapping(sf: "checkmark.seal", unicode: "☑", ascii: "[x]")
        let overlay = OverlaySymbolSet(base: base, overrides: [.check: customCheck])

        #expect(overlay.mapping(for: .check).unicode == "☑")          // overridden
        #expect(overlay.mapping(for: .close).unicode == base.mapping(for: .close).unicode) // pass-through
    }

    @Test("Token vocabulary types are Sendable")
    func tokensAreSendable() {
        // Compile-time: each call only type-checks if its argument is Sendable.
        requireSendable(ColorRole.accent)
        requireSendable(TypeRole.title)
        requireSendable(SpaceToken.m)
        requireSendable(Elevation.overlay)
        requireSendable(MotionRole.standard)
        requireSendable(WidgetState.focused)
        requireSendable(Symbol.check)
        requireSendable(GlyphMapping(sf: "a", unicode: "b", ascii: "c"))
        requireSendable(DefaultSymbolSet())

        // Runtime: the Sendable vocabulary is also intact and resolvable.
        #expect(Symbol.allCases.count == 12)
        #expect(DefaultSymbolSet().mapping(for: .check).unicode == "✓")
    }
}
