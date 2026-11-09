// ColorFGBGTests.swift
// SwiftCLIKit

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ColorFGBG")
struct ColorFGBGTests {

    @Test("15;0 is light on dark")
    func lightOnDark() {
        let parsed = ColorFGBG.parse("15;0")
        #expect(parsed == ColorFGBG(foreground: 15, background: 0, isDark: true))
    }

    @Test("0;15 is dark on light")
    func darkOnLight() {
        let parsed = ColorFGBG.parse("0;15")
        #expect(parsed == ColorFGBG(foreground: 0, background: 15, isDark: false))
    }

    @Test("7;0 has a dark background")
    func sevenZero() {
        #expect(ColorFGBG.parse("7;0") == ColorFGBG(foreground: 7, background: 0, isDark: true))
    }

    @Test("three-part form takes the last field as background")
    func threePart() {
        #expect(ColorFGBG.parse("15;default;0") == ColorFGBG(foreground: 15, background: 0, isDark: true))
        #expect(ColorFGBG.parse("0;default;7") == ColorFGBG(foreground: 0, background: 7, isDark: false))
    }

    @Test("background index classes", arguments: [
        (0, true), (1, true), (2, true), (3, true), (4, true), (5, true), (6, true),
        (8, true), (7, false), (15, false),
    ])
    func backgroundClasses(index: Int, dark: Bool) {
        #expect(ColorFGBG.parse("9;\(index)")?.isDark == dark)
    }

    @Test("indices with no stated class are unknown", arguments: [9, 10, 11, 12, 13, 14, 100, 255])
    func unknownClass(index: Int) {
        let parsed = ColorFGBG.parse("0;\(index)")
        #expect(parsed?.background == index)
        #expect(parsed?.isDark == nil)
    }

    @Test("default;default is well formed but says nothing")
    func defaults() {
        #expect(ColorFGBG.parse("default;default") == ColorFGBG(foreground: nil, background: nil, isDark: nil))
    }

    @Test("empty and garbage return nil", arguments: [
        "", ";", "garbage", "15", "15;", ";0", "a;b", "1;2;3;4", "-1;0", "15;0x", "256;0", "0;256", "1.5;0",
    ])
    func malformed(input: String) {
        #expect(ColorFGBG.parse(input) == nil)
    }
}
