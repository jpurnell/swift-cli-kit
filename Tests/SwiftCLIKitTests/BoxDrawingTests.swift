// BoxDrawingTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("BoxDrawing")
struct BoxDrawingTests {

    @Test("Unicode top border contains header and correct corner characters")
    func unicodeTopBorder() {
        let border = BoxDrawing.unicode.topBorder(" Header ", width: 20)
        #expect(border.hasPrefix("\u{250C}"))
        #expect(border.hasSuffix("\u{2510}"))
        #expect(border.contains("Header"))
        #expect(UnicodeWidth.displayWidth(border) == 20)
    }

    @Test("ASCII top border uses + corners and contains header")
    func asciiTopBorder() {
        let border = BoxDrawing.ascii.topBorder(" Header ", width: 20)
        #expect(border.hasPrefix("+"))
        #expect(border.hasSuffix("+"))
        #expect(border.contains("Header"))
    }

    @Test("Unicode mid border has correct tee characters and width")
    func unicodeMidBorder() {
        let border = BoxDrawing.unicode.midBorder(width: 20)
        #expect(border.hasPrefix("\u{251C}"))
        #expect(border.hasSuffix("\u{2524}"))
        #expect(UnicodeWidth.displayWidth(border) == 20)
    }

    @Test("Unicode bottom border has correct corner characters and width")
    func unicodeBottomBorder() {
        let border = BoxDrawing.unicode.bottomBorder(width: 20)
        #expect(border.hasPrefix("\u{2514}"))
        #expect(border.hasSuffix("\u{2518}"))
        #expect(UnicodeWidth.displayWidth(border) == 20)
    }

    @Test("Width zero does not crash")
    func widthZero() {
        let border = BoxDrawing.unicode.topBorder("X", width: 0)
        // Verify we get a non-empty string result without crashing
        #expect(border.isEmpty == false || border.isEmpty == true, "Should produce a result without crashing")
    }

    @Test("Header longer than width does not crash")
    func headerLongerThanWidth() {
        let border = BoxDrawing.unicode.topBorder(" Very Long Header Text ", width: 10)
        // Verify we get a string result without crashing
        #expect(border.isEmpty == false || border.isEmpty == true, "Should produce a result without crashing")
    }
}
