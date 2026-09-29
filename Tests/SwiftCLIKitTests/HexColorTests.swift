// HexColorTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("HexColor")
struct HexColorTests {

    @Test("Red hex maps to ANSI red")
    func redHex() {
        #expect(HexColor.toANSI8("#e53935") == .red)
    }

    @Test("Green hex maps to ANSI green")
    func greenHex() {
        #expect(HexColor.toANSI8("#4caf50") == .green)
    }

    @Test("Blue hex maps to ANSI blue")
    func blueHex() {
        #expect(HexColor.toANSI8("#2196f3") == .blue)
    }

    @Test("White hex maps to ANSI white")
    func whiteHex() {
        #expect(HexColor.toANSI8("#ffffff") == .white)
    }

    @Test("Black hex maps to ANSI black")
    func blackHex() {
        #expect(HexColor.toANSI8("#000000") == .black)
    }

    @Test("Case insensitive hex produces same result")
    func caseInsensitive() {
        #expect(HexColor.toANSI8("#FF0000") == HexColor.toANSI8("#ff0000"))
    }

    @Test("Hex without hash prefix works")
    func withoutHash() {
        #expect(HexColor.toANSI8("e53935") == .red)
    }

    @Test("Malformed hex returns nil")
    func malformed() {
        #expect(HexColor.toANSI8("not-a-color") == nil)
    }

    @Test("Empty string returns nil")
    func emptyString() {
        #expect(HexColor.toANSI8("") == nil)
    }

    @Test("toANSIEscape for valid red hex returns ANSI red foreground")
    func toEscapeValid() {
        #expect(HexColor.toANSIEscape("#e53935") == "\u{001B}[31m")
    }

    @Test("toANSIEscape for invalid hex returns empty string")
    func toEscapeInvalid() {
        #expect(HexColor.toANSIEscape("garbage") == "")
    }
}
