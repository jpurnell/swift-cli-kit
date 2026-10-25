// ANSIStringMetricsTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ANSIStringMetrics")
struct ANSIStringMetricsTests {

    @Test("Plain text visible length equals character count")
    func plainText() {
        #expect(ANSIStringMetrics.visibleLength("hello") == 5)
    }

    @Test("ANSI colored text visible length excludes escape sequences")
    func ansiColored() {
        #expect(ANSIStringMetrics.visibleLength("\u{001B}[31mred\u{001B}[0m") == 3)
    }

    @Test("Multiple ANSI escapes are stripped from visible length")
    func multipleEscapes() {
        #expect(ANSIStringMetrics.visibleLength("\u{001B}[1m\u{001B}[31mbold red\u{001B}[0m") == 8)
    }

    @Test("CJK characters with ANSI have correct visible width")
    func cjkWithANSI() {
        #expect(ANSIStringMetrics.visibleLength("\u{001B}[31m\u{4E2D}\u{6587}\u{001B}[0m") == 4)
    }

    @Test("Emoji with ANSI has correct visible width")
    func emojiWithANSI() {
        #expect(ANSIStringMetrics.visibleLength("\u{001B}[32m\u{1F600}\u{001B}[0m") == 2)
    }

    @Test("padVisible pads string to target visible width")
    func padVisible() {
        let padded = ANSIStringMetrics.padVisible("hi", to: 10)
        #expect(ANSIStringMetrics.visibleLength(padded) == 10)
    }

    @Test("padVisible on already-wide string is unchanged")
    func padAlreadyWide() {
        let result = ANSIStringMetrics.padVisible("hello world", to: 5)
        #expect(result == "hello world")
    }

    @Test("padVisible on CJK character pads correctly")
    func padCJK() {
        let padded = ANSIStringMetrics.padVisible("\u{4E2D}", to: 4)
        #expect(ANSIStringMetrics.visibleLength(padded) == 4)
    }

    @Test("truncateVisible truncates plain text to target width")
    func truncateBasic() {
        let truncated = ANSIStringMetrics.truncateVisible("hello world", to: 5)
        #expect(ANSIStringMetrics.visibleLength(truncated) == 5)
        #expect(truncated.hasPrefix("hello"))
    }

    @Test("truncateVisible on colored text includes reset at end")
    func truncateWithANSI() {
        let colored = "\u{001B}[31mhello world\u{001B}[0m"
        let truncated = ANSIStringMetrics.truncateVisible(colored, to: 5)
        #expect(truncated.contains("\u{001B}[0m"))
    }

    @Test("truncateVisible on wide boundary pads instead of splitting a wide character")
    func truncateWideBoundary() {
        // "A" = width 1, "中" = width 2, "B" = width 1 → total 4
        let truncated = ANSIStringMetrics.truncateVisible("A\u{4E2D}B", to: 2)
        #expect(ANSIStringMetrics.visibleLength(truncated) == 2)
    }

    @Test("Empty string has visible length 0")
    func emptyString() {
        #expect(ANSIStringMetrics.visibleLength("") == 0)
    }

    @Test("Truncate mid-ANSI sequence appends reset to prevent style bleeding")
    func truncateMidANSISequence() {
        let colored = "\u{001B}[31mhello\u{001B}[0m"
        let truncated = ANSIStringMetrics.truncateVisible(colored, to: 2)
        // Should contain only 2 visible chars and end with a reset sequence
        #expect(ANSIStringMetrics.visibleLength(truncated) <= 2)
        #expect(truncated.contains("\u{001B}[0m"))
    }

    @Test("Truncate preserves complete ANSI when width exceeds visible length")
    func truncatePreservesCompleteANSI() {
        let colored = "\u{001B}[31mhi\u{001B}[0m"
        let truncated = ANSIStringMetrics.truncateVisible(colored, to: 5)
        // Visible length is 2, which fits within 5, so the string should be unchanged
        #expect(truncated == colored)
    }

    // MARK: - Middle elision

    @Test("elideMiddle leaves a string that already fits unchanged")
    func elideMiddleFits() {
        #expect(ANSIStringMetrics.elideMiddle("HarborUI", to: 20) == "HarborUI")
    }

    @Test("elideMiddle with non-positive width returns empty")
    func elideMiddleZeroWidth() {
        #expect(ANSIStringMetrics.elideMiddle("HarborUI", to: 0) == "")
    }

    @Test("elideMiddle with width 1 returns just the ellipsis")
    func elideMiddleWidthOne() {
        #expect(ANSIStringMetrics.elideMiddle("HarborUI", to: 1) == "…")
    }

    @Test("elideMiddle never exceeds the width budget and inserts an ellipsis")
    func elideMiddleWidthBound() {
        let result = ANSIStringMetrics.elideMiddle("BioFeedbackKit", to: 10)
        #expect(ANSIStringMetrics.visibleLength(result) <= 10)
        #expect(result.contains("…"))
    }

    @Test("elideMiddle keeps head and full camel-case Kit suffix")
    func elideMiddleKitSuffix() {
        #expect(ANSIStringMetrics.elideMiddle("BioFeedbackKit", to: 10) == "BioFee…Kit")
    }

    @Test("elideMiddle keeps a two-letter acronym suffix whole")
    func elideMiddleUISuffix() {
        #expect(ANSIStringMetrics.elideMiddle("HarborUI", to: 6) == "Har…UI")
    }

    @Test("elideMiddle favors a full acronym suffix over an even split")
    func elideMiddleAcronymSuffix() {
        // An even split would cut "BASIC" to "ASIC"; favoring the suffix keeps it whole.
        let result = ANSIStringMetrics.elideMiddle("ApplesoftBASIC", to: 10)
        #expect(result.hasSuffix("BASIC"))
        #expect(ANSIStringMetrics.visibleLength(result) <= 10)
    }

    @Test("elideMiddle distinguishes sibling modules by their suffix")
    func elideMiddleDistinguishesSiblings() {
        let kit = ANSIStringMetrics.elideMiddle("HarborKit", to: 6)
        let ui = ANSIStringMetrics.elideMiddle("HarborUI", to: 6)
        #expect(kit != ui)
        #expect(kit.hasSuffix("Kit"))
        #expect(ui.hasSuffix("UI"))
    }

    @Test("elideMiddle on a single lowercase token still elides within budget")
    func elideMiddleLowercaseToken() {
        let result = ANSIStringMetrics.elideMiddle("harbor", to: 5)
        #expect(ANSIStringMetrics.visibleLength(result) <= 5)
        #expect(result.contains("…"))
    }

    @Test("elideMiddle does not split a wide grapheme and respects the budget")
    func elideMiddleWideChars() {
        // "中" and "文" are width 2 each.
        let result = ANSIStringMetrics.elideMiddle("\u{4E2D}\u{6587}AB\u{4E2D}\u{6587}", to: 5)
        #expect(ANSIStringMetrics.visibleLength(result) <= 5)
        #expect(result.contains("…"))
    }

    @Test("elideMiddle strips interior ANSI and returns plain visible text")
    func elideMiddleStripsANSI() {
        let colored = "\u{001B}[32mBioFeedbackKit\u{001B}[0m"
        let result = ANSIStringMetrics.elideMiddle(colored, to: 10)
        #expect(result == "BioFee…Kit")
    }
    // MARK: - plainText: exactly CSI `ESC [ [0-9;]* letter` is removed

    @Test("plainText strips SGR and cursor CSI sequences, keeping the text between them")
    func plainTextStripsCSI() {
        #expect(ANSIStringMetrics.plainText("\u{001B}[1;31mred\u{001B}[0m \u{001B}[2Kx\u{001B}[10;5H") == "red x")
    }

    @Test("plainText strips a parameterless CSI such as ESC [ m")
    func plainTextStripsParameterlessCSI() {
        #expect(ANSIStringMetrics.plainText("a\u{001B}[mb") == "ab")
    }

    @Test("plainText leaves a CSI with a private-mode marker untouched")
    func plainTextKeepsPrivateModeCSI() {
        let s = "\u{001B}[?25lhidden"
        #expect(ANSIStringMetrics.plainText(s) == s)
    }

    @Test("plainText leaves an unterminated CSI untouched")
    func plainTextKeepsUnterminatedCSI() {
        let s = "abc\u{001B}[12;"
        #expect(ANSIStringMetrics.plainText(s) == s)
    }

    @Test("plainText leaves a lone ESC and non-CSI escapes untouched")
    func plainTextKeepsNonCSIEscapes() {
        let s = "\u{001B}x \u{001B}]52;c;aGk=\u{07} \u{001B}"
        #expect(ANSIStringMetrics.plainText(s) == s)
    }

    @Test("plainText resumes after an incomplete CSI and still strips the next one")
    func plainTextResumesAfterIncompleteCSI() {
        #expect(ANSIStringMetrics.plainText("\u{001B}[1;\u{001B}[31mz") == "\u{001B}[1;z")
    }

    @Test("plainText does not treat a non-ASCII letter as a CSI final byte")
    func plainTextRequiresASCIIFinalByte() {
        let s = "\u{001B}[1\u{00E9}"
        #expect(ANSIStringMetrics.plainText(s) == s)
    }

    @Test("plainText keeps combining marks and emoji around stripped escapes")
    func plainTextKeepsGraphemes() {
        #expect(ANSIStringMetrics.plainText("e\u{0301}\u{001B}[0m\u{1F44D}\u{1F3FD}") == "e\u{0301}\u{1F44D}\u{1F3FD}")
    }
}
