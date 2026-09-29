// HexColorV2Tests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("HexColor v0.2.0")
struct HexColorV2Tests {

    @Test("toColor valid hex returns truecolor")
    func toColorValid() {
        let color = HexColor.toColor("#FF8800")
        #expect(color == .truecolor(r: 0xFF, g: 0x88, b: 0x00))
    }

    @Test("toColor invalid hex returns nil")
    func toColorInvalid() {
        #expect(HexColor.toColor("not-a-color") == nil)
    }

    @Test("toEscape at truecolor capability produces RGB escape")
    func toEscapeTruecolor() {
        let escape = HexColor.toEscape("#FF0000", capability: .truecolor)
        #expect(escape == "\u{001B}[38;2;255;0;0m")
    }

    @Test("toEscape at extended capability produces 256-color escape")
    func toEscapeExtended() {
        let escape = HexColor.toEscape("#FF0000", capability: .extended)
        #expect(escape.hasPrefix("\u{001B}[38;5;"))
    }

    @Test("toEscape at basic capability produces ANSI 8-color escape")
    func toEscapeBasic() {
        let escape = HexColor.toEscape("#FF0000", capability: .basic)
        #expect(escape == ANSICodes.fg(.red))
    }

    @Test("toEscape at none capability produces empty string")
    func toEscapeNone() {
        let escape = HexColor.toEscape("#FF0000", capability: .none)
        #expect(escape == "")
    }

    @Test("Backward compat: toANSI8 still works")
    func backwardCompatToANSI8() {
        #expect(HexColor.toANSI8("#e53935") == .red)
    }

    @Test("Backward compat: toANSIEscape still works")
    func backwardCompatToANSIEscape() {
        #expect(HexColor.toANSIEscape("#e53935") == "\u{001B}[31m")
    }
}
