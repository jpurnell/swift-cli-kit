// ClipboardTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Clipboard")
struct ClipboardTests {

    @Test("writeSequence produces correct OSC 52 with base64")
    func writeSequence() {
        let seq = Clipboard.writeSequence("hello")
        // OSC 52: ESC ] 52 ; c ; <base64> BEL
        // "hello" in base64 is "aGVsbG8="
        #expect(seq == "\u{1B}]52;c;aGVsbG8=\u{07}")
    }

    @Test("readSequence produces correct OSC 52 query")
    func readSequence() {
        let seq = Clipboard.readSequence()
        // OSC 52 read request: ESC ] 52 ; c ; ? BEL
        #expect(seq == "\u{1B}]52;c;?\u{07}")
    }

    @Test("writeSequence with empty string produces valid OSC 52")
    func writeSequenceEmpty() {
        let seq = Clipboard.writeSequence("")
        // Empty string base64 is ""
        #expect(seq == "\u{1B}]52;c;\u{07}")
    }

    @Test("writeSequence with unicode produces correct UTF-8 base64")
    func writeSequenceUnicode() {
        let seq = Clipboard.writeSequence("caf\u{00E9}")
        // "cafe\u{0301}" with precomposed e-acute (U+00E9) = UTF-8 bytes: 63 61 66 C3 A9
        // base64 of those bytes: "Y2Fmw6k="
        let expected = "\u{1B}]52;c;Y2Fmw6k=\u{07}"
        #expect(seq == expected)
    }
}
