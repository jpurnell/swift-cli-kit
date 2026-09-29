// UnicodeWidthTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("UnicodeWidth")
struct UnicodeWidthTests {

    @Test("ASCII letter is width 1")
    func asciiLetter() {
        #expect(UnicodeWidth.width(of: Character("A")) == 1)
    }

    @Test("CJK ideograph is width 2")
    func cjkIdeograph() {
        #expect(UnicodeWidth.width(of: Character("\u{4E2D}")) == 2)
    }

    @Test("CJK string display width is sum of character widths")
    func cjkString() {
        #expect(UnicodeWidth.displayWidth("\u{4E2D}\u{6587}") == 4)
    }

    @Test("Fullwidth letter is width 2")
    func fullwidthLetter() {
        #expect(UnicodeWidth.width(of: Character("\u{FF21}")) == 2)
    }

    @Test("Halfwidth katakana is width 1")
    func halfwidthKatakana() {
        #expect(UnicodeWidth.width(of: Character("\u{FF71}")) == 1)
    }

    @Test("Combining mark grapheme cluster is width 1")
    func combiningMark() {
        #expect(UnicodeWidth.width(of: Character("e\u{0301}")) == 1)
    }

    @Test("Basic emoji is width 2")
    func emojiBasic() {
        #expect(UnicodeWidth.width(of: Character("\u{1F600}")) == 2)
    }

    @Test("Emoji with VS16 is width 2")
    func emojiVS16() {
        #expect(UnicodeWidth.width(of: Character("\u{263A}\u{FE0F}")) == 2)
    }

    @Test("Emoji ZWJ sequence is width 2")
    func emojiZWJ() {
        #expect(UnicodeWidth.width(of: Character("\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}")) == 2)
    }

    @Test("Flag emoji is width 2")
    func flagEmoji() {
        #expect(UnicodeWidth.width(of: Character("\u{1F1EF}\u{1F1F5}")) == 2)
    }

    @Test("Zero-width joiner is width 0")
    func zeroWidthJoiner() {
        #expect(UnicodeWidth.width(of: Character("\u{200D}")) == 0)
    }

    @Test("Zero-width space is width 0")
    func zeroWidthSpace() {
        #expect(UnicodeWidth.width(of: Character("\u{200B}")) == 0)
    }

    @Test("Control character NUL is width 0 via scalar overload")
    func controlCharacter() {
        #expect(UnicodeWidth.width(of: Unicode.Scalar(0)) == 0)
    }

    @Test("Tab is width 0 via scalar overload")
    func tab() {
        #expect(UnicodeWidth.width(of: Unicode.Scalar(9)) == 0)
    }

    @Test("Soft hyphen is width 1")
    func softHyphen() {
        #expect(UnicodeWidth.width(of: Character("\u{00AD}")) == 1)
    }

    @Test("Mixed ASCII and CJK string display width")
    func mixedASCICJK() {
        #expect(UnicodeWidth.displayWidth("AB\u{4E2D}CD") == 6)
    }

    @Test("Empty string has display width 0")
    func emptyString() {
        #expect(UnicodeWidth.displayWidth("") == 0)
    }

    @Test("Multiple emoji display width")
    func multipleEmoji() {
        #expect(UnicodeWidth.displayWidth("\u{1F600}\u{1F1EF}\u{1F1F5}") == 4)
    }
}
