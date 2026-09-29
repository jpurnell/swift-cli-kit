// ANSICodesV2Tests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ANSICodes v0.2.0")
struct ANSICodesV2Tests {

    @Test("fg256 produces 256-color foreground sequence")
    func fg256() {
        #expect(ANSICodes.fg256(196) == "\u{001B}[38;5;196m")
    }

    @Test("bg256 produces 256-color background sequence")
    func bg256() {
        #expect(ANSICodes.bg256(82) == "\u{001B}[48;5;82m")
    }

    @Test("fgRGB produces truecolor foreground sequence")
    func fgRGB() {
        #expect(ANSICodes.fgRGB(255, 128, 0) == "\u{001B}[38;2;255;128;0m")
    }

    @Test("bgRGB produces truecolor background sequence")
    func bgRGB() {
        #expect(ANSICodes.bgRGB(0, 128, 255) == "\u{001B}[48;2;0;128;255m")
    }

    @Test("fg256 index 0 produces black foreground")
    func fg256Zero() {
        #expect(ANSICodes.fg256(0) == "\u{001B}[38;5;0m")
    }

    @Test("bg256 index 255 produces max palette background")
    func bg256Max() {
        #expect(ANSICodes.bg256(255) == "\u{001B}[48;5;255m")
    }

    @Test("strikethrough produces SGR 9 sequence")
    func strikethrough() {
        #expect(ANSICodes.strikethrough == "\u{001B}[9m")
    }

    @Test("overline produces SGR 53 sequence")
    func overline() {
        #expect(ANSICodes.overline == "\u{001B}[53m")
    }

    @Test("underlineCurly produces SGR 4:3 sequence")
    func underlineCurly() {
        #expect(ANSICodes.underlineCurly == "\u{001B}[4:3m")
    }

    @Test("underlineDouble produces SGR 21 sequence")
    func underlineDouble() {
        #expect(ANSICodes.underlineDouble == "\u{001B}[21m")
    }

    @Test("underlineDotted produces SGR 4:4 sequence")
    func underlineDotted() {
        #expect(ANSICodes.underlineDotted == "\u{001B}[4:4m")
    }

    @Test("fgRGB all zeros produces black truecolor foreground")
    func fgRGBZeros() {
        #expect(ANSICodes.fgRGB(0, 0, 0) == "\u{001B}[38;2;0;0;0m")
    }
}
