// ColorNegotiationTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ColorNegotiation")
struct ColorNegotiationTests {

    @Test("fgEscape truecolor at .truecolor capability")
    func fgEscapeTruecolor() {
        let escape = ColorNegotiation.fgEscape(.truecolor(r: 255, g: 0, b: 0), capability: .truecolor)
        #expect(escape == "\u{001B}[38;2;255;0;0m")
    }

    @Test("fgEscape ansi256 at .extended capability")
    func fgEscapeAnsi256() {
        let escape = ColorNegotiation.fgEscape(.ansi256(196), capability: .extended)
        #expect(escape == "\u{001B}[38;5;196m")
    }

    @Test("fgEscape ansi8 at .basic capability")
    func fgEscapeAnsi8() {
        let escape = ColorNegotiation.fgEscape(.ansi8(.green), capability: .basic)
        #expect(escape == ANSICodes.fg(.green))
    }

    @Test("fgEscape at .none returns empty string")
    func fgEscapeNone() {
        let escape = ColorNegotiation.fgEscape(.truecolor(r: 255, g: 0, b: 0), capability: .none)
        #expect(escape == "")
    }

    @Test("bgEscape truecolor at .truecolor capability")
    func bgEscapeTruecolor() {
        let escape = ColorNegotiation.bgEscape(.truecolor(r: 0, g: 128, b: 255), capability: .truecolor)
        #expect(escape == "\u{001B}[48;2;0;128;255m")
    }

    @Test("bgEscape at .none returns empty string")
    func bgEscapeNone() {
        let escape = ColorNegotiation.bgEscape(.ansi8(.blue), capability: .none)
        #expect(escape == "")
    }

    @Test("Auto-downsample: truecolor color at .basic capability")
    func autoDownsampleTruecolorToBasic() {
        let escape = ColorNegotiation.fgEscape(.truecolor(r: 255, g: 0, b: 0), capability: .basic)
        // Should auto-downsample to ANSI red
        #expect(escape == ANSICodes.fg(.red))
    }

    @Test("Auto-downsample: truecolor color at .extended capability uses fg256")
    func autoDownsampleTruecolorToExtended() {
        let escape = ColorNegotiation.fgEscape(.truecolor(r: 255, g: 0, b: 0), capability: .extended)
        // Should produce a 256-color escape, not empty
        #expect(escape.hasPrefix("\u{001B}[38;5;"))
    }

    @Test("detect returns a valid ColorCapability")
    func detectReturnsValid() {
        let cap = ColorNegotiation.detect()
        #expect(cap.rawValue >= 0 && cap.rawValue <= 3)
    }

    @Test("fgEscape ansi8 red at basic equals ANSICodes.fg(.red)")
    func fgEscapeAnsi8Red() {
        let escape = ColorNegotiation.fgEscape(.ansi8(.red), capability: .basic)
        #expect(escape == ANSICodes.fg(.red))
    }

    @Test("bgEscape ansi8 blue at basic equals ANSICodes.bg(.blue)")
    func bgEscapeAnsi8Blue() {
        let escape = ColorNegotiation.bgEscape(.ansi8(.blue), capability: .basic)
        #expect(escape == ANSICodes.bg(.blue))
    }

    @Test("fgEscape truecolor at .extended uses fg256")
    func fgEscapeTruecolorAtExtended() {
        let escape = ColorNegotiation.fgEscape(.truecolor(r: 0, g: 255, b: 0), capability: .extended)
        #expect(escape.hasPrefix("\u{001B}[38;5;"))
    }

    @Test("Truecolor green downsampled to basic equals ANSI green")
    func conflictingEnvVars() {
        // A truecolor pure green at basic capability should downsample to ANSI green
        let escape = ColorNegotiation.fgEscape(.truecolor(r: 0, g: 255, b: 0), capability: .basic)
        #expect(escape == ANSICodes.fg(.green))
    }
}
