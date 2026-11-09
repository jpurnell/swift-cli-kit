// TerminalColorsTests.swift
// SwiftCLIKit

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("TerminalColors")
struct TerminalColorsTests {

    private let black = TerminalRGB(r: 0, g: 0, b: 0)
    private let white = TerminalRGB(r: 255, g: 255, b: 255)
    private let cream = TerminalRGB(r: 0xFD, g: 0xF6, b: 0xE3)

    @Test("explicit dark")
    func explicitDark() {
        let result = TerminalColors.resolve(environment: ["SWIFTCLIKIT_BACKGROUND": "dark"], queried: nil)
        #expect(result == TerminalColors(background: nil, foreground: nil, isDark: true, confidence: .explicit))
    }

    @Test("explicit light")
    func explicitLight() {
        let result = TerminalColors.resolve(environment: ["SWIFTCLIKIT_BACKGROUND": "light"], queried: nil)
        #expect(result == TerminalColors(background: nil, foreground: nil, isDark: false, confidence: .explicit))
    }

    @Test("explicit hex background derives isDark from luminance")
    func explicitHex() {
        let light = TerminalColors.resolve(environment: ["SWIFTCLIKIT_BACKGROUND": "#FDF6E3"], queried: nil)
        #expect(light == TerminalColors(background: cream, foreground: nil, isDark: false, confidence: .explicit))
        let dark = TerminalColors.resolve(environment: ["SWIFTCLIKIT_BACKGROUND": "#002b36"], queried: nil)
        #expect(dark.background == TerminalRGB(r: 0, g: 0x2B, b: 0x36))
        #expect(dark.isDark)
        #expect(dark.confidence == .explicit)
    }

    @Test("explicit foreground is carried")
    func explicitForeground() {
        let env = ["SWIFTCLIKIT_BACKGROUND": "dark", "SWIFTCLIKIT_FOREGROUND": "#00FF00"]
        let result = TerminalColors.resolve(environment: env, queried: nil)
        #expect(result.foreground == TerminalRGB(r: 0, g: 255, b: 0))
    }

    @Test("explicit beats queried, hint and assumption")
    func explicitPrecedence() {
        let env = ["SWIFTCLIKIT_BACKGROUND": "light", "COLORFGBG": "15;0"]
        let queried = TerminalColors.QueryResult(background: black, foreground: white)
        let result = TerminalColors.resolve(environment: env, queried: queried)
        #expect(result.isDark == false)
        #expect(result.confidence == .explicit)
        #expect(result.background == nil)
        // Foreground was not overridden, so the query's foreground is kept.
        #expect(result.foreground == white)
    }

    @Test("explicit foreground beats queried foreground")
    func explicitForegroundPrecedence() {
        let env = ["SWIFTCLIKIT_FOREGROUND": "#FF0000"]
        let queried = TerminalColors.QueryResult(background: black, foreground: white)
        let result = TerminalColors.resolve(environment: env, queried: queried)
        #expect(result.foreground == TerminalRGB(r: 255, g: 0, b: 0))
        #expect(result.background == black)
        #expect(result.confidence == .queried)
    }

    @Test("queried background beats COLORFGBG")
    func queriedBeatsHint() {
        let queried = TerminalColors.QueryResult(background: cream, foreground: black)
        let result = TerminalColors.resolve(environment: ["COLORFGBG": "15;0"], queried: queried)
        #expect(result == TerminalColors(background: cream, foreground: black, isDark: false, confidence: .queried))
    }

    @Test("queried dark background")
    func queriedDark() {
        let queried = TerminalColors.QueryResult(background: black, foreground: nil)
        let result = TerminalColors.resolve(environment: [:], queried: queried)
        #expect(result == TerminalColors(background: black, foreground: nil, isDark: true, confidence: .queried))
    }

    @Test("a query with only a foreground falls through to the hint but keeps the foreground")
    func queriedForegroundOnly() {
        let queried = TerminalColors.QueryResult(background: nil, foreground: white)
        let result = TerminalColors.resolve(environment: ["COLORFGBG": "0;15"], queried: queried)
        #expect(result == TerminalColors(background: nil, foreground: white, isDark: false, confidence: .hinted))
    }

    @Test("COLORFGBG hints dark and light")
    func hinted() {
        let dark = TerminalColors.resolve(environment: ["COLORFGBG": "15;0"], queried: nil)
        #expect(dark == TerminalColors(background: nil, foreground: nil, isDark: true, confidence: .hinted))
        let light = TerminalColors.resolve(environment: ["COLORFGBG": "0;15"], queried: nil)
        #expect(light == TerminalColors(background: nil, foreground: nil, isDark: false, confidence: .hinted))
    }

    @Test("unknown COLORFGBG falls through to assumed dark")
    func unknownHint() {
        for value in ["default;default", "0;12", "garbage", ""] {
            let result = TerminalColors.resolve(environment: ["COLORFGBG": value], queried: nil)
            #expect(result == TerminalColors(background: nil, foreground: nil, isDark: true, confidence: .assumed))
        }
    }

    @Test("empty environment assumes dark")
    func assumed() {
        let result = TerminalColors.resolve(environment: [:], queried: nil)
        #expect(result == TerminalColors(background: nil, foreground: nil, isDark: true, confidence: .assumed))
    }

    @Test("invalid overrides are ignored, not fatal")
    func invalidOverrides() {
        for value in ["", "purple", "#12", "#GGGGGG", "DARK "] {
            let env = ["SWIFTCLIKIT_BACKGROUND": value, "SWIFTCLIKIT_FOREGROUND": value, "COLORFGBG": "0;15"]
            let result = TerminalColors.resolve(environment: env, queried: nil)
            #expect(result == TerminalColors(background: nil, foreground: nil, isDark: false, confidence: .hinted))
        }
    }

    @Test("NO_COLOR does not change detection")
    func noColor() {
        let result = TerminalColors.resolve(environment: ["NO_COLOR": "1", "COLORFGBG": "0;15"], queried: nil)
        #expect(result == TerminalColors(background: nil, foreground: nil, isDark: false, confidence: .hinted))
    }

    @Test("override keywords are case-insensitive")
    func caseInsensitive() {
        let result = TerminalColors.resolve(environment: ["SWIFTCLIKIT_BACKGROUND": "Light"], queried: nil)
        #expect(result.isDark == false)
        #expect(result.confidence == .explicit)
    }
}
