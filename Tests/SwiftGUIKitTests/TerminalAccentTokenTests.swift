// TerminalAccentTokenTests.swift
// SwiftGUIKit
//
// The terminal `.accent` role is the shared DesignTokens accent (Apple system orange),
// not `Theme.primary`. Exact expected values are written out so a change to either
// the package or the resolver fails here, and one test reads the package directly so
// drift between the two cannot pass unnoticed.

import Testing
import DesignTokens
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("TerminalTokenResolver accent from DesignTokens")
struct TerminalAccentTokenTests {

    let resolver = TerminalTokenResolver(theme: .dark)

    private func context(_ appearance: DesignContext.Appearance, _ depth: ColorCapability) -> DesignContext {
        DesignContext(appearance: appearance, colorDepth: depth, glyphCapability: .unicode)
    }

    // MARK: Exact values

    @Test("dark appearance, truecolor: #FF9230")
    func darkTruecolor() {
        #expect(resolver.color(.accent, in: context(.dark, .truecolor)).color
                == .truecolor(r: 0xFF, g: 0x92, b: 0x30))
    }

    @Test("light appearance, truecolor: #FF8D28")
    func lightTruecolor() {
        #expect(resolver.color(.accent, in: context(.light, .truecolor)).color
                == .truecolor(r: 0xFF, g: 0x8D, b: 0x28))
    }

    @Test("256-colour degradation: nearest cube entries 209 (dark) and 208 (light)")
    func extended() {
        #expect(resolver.color(.accent, in: context(.dark, .extended)).color == .ansi256(209))
        #expect(resolver.color(.accent, in: context(.light, .extended)).color == .ansi256(208))
    }

    @Test("16-colour degradation: hue 28 degrees lands on yellow in both appearances")
    func basic() {
        #expect(resolver.color(.accent, in: context(.dark, .basic)).color == .ansi8(.yellow))
        #expect(resolver.color(.accent, in: context(.light, .basic)).color == .ansi8(.yellow))
    }

    @Test("mono floor: default colour, bold, as before")
    func mono() {
        let r = resolver.color(.accent, in: context(.dark, .none))
        #expect(r.color == .default)
        #expect(r.attributes.contains(.bold))
        #expect(r.monoPrefix == nil)
    }

    @Test("high-contrast and system appearances resolve as dark")
    func otherAppearances() {
        let dark = resolver.color(.accent, in: context(.dark, .truecolor)).color
        #expect(resolver.color(.accent, in: context(.highContrast, .truecolor)).color == dark)
        #expect(resolver.color(.accent, in: context(.system, .truecolor)).color == dark)
    }

    @Test("the theme no longer decides the accent")
    func themeIndependent() {
        let light = TerminalTokenResolver(theme: .light).color(.accent, in: context(.dark, .truecolor)).color
        #expect(light == resolver.color(.accent, in: context(.dark, .truecolor)).color)
    }

    // MARK: Drift

    @Test("terminal accent equals the DesignTokens value in both appearances")
    func matchesDesignTokens() {
        let dark = ColorToken.accent.value(in: .dark)
        let light = ColorToken.accent.value(in: .light)
        #expect(resolver.color(.accent, in: context(.dark, .truecolor)).color
                == .truecolor(r: dark.red, g: dark.green, b: dark.blue))
        #expect(resolver.color(.accent, in: context(.light, .truecolor)).color
                == .truecolor(r: light.red, g: light.green, b: light.blue))
    }

    // MARK: Untouched roles

    @Test("other roles still come from the theme and keep their status prefixes")
    func otherRolesUnchanged() {
        #expect(resolver.color(.warning, in: .terminalTruecolor).color == Theme.dark.warning)
        #expect(resolver.color(.separator, in: .terminalTruecolor).color == Theme.dark.border)
        #expect(resolver.color(.success, in: .terminalMono).monoPrefix == "+")
        #expect(resolver.color(.destructive, in: .terminalMono).monoPrefix == "!")
        #expect(resolver.color(.warning, in: .terminalMono).monoPrefix == "*")
    }
}
