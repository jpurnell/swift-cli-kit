// OSCColorReplyTests.swift
// SwiftCLIKit

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("OSCColorReply")
struct OSCColorReplyTests {

    private let esc = "\u{1B}"
    private let bel = "\u{07}"

    @Test("4-digit channels with BEL terminator scale to 8 bits")
    func fourDigitBEL() {
        let reply = OSCColorReply.parse("\(esc)]11;rgb:ffff/8080/0000\(bel)")
        #expect(reply == OSCColorReply(target: .background, color: TerminalRGB(r: 255, g: 128, b: 0)))
    }

    @Test("2-digit channels with ST terminator")
    func twoDigitST() {
        let reply = OSCColorReply.parse("\(esc)]11;rgb:ff/80/00\(esc)\\")
        #expect(reply?.color == TerminalRGB(r: 255, g: 128, b: 0))
        #expect(reply?.target == .background)
    }

    @Test("1-digit channels scale by 255/15")
    func oneDigit() {
        let reply = OSCColorReply.parse("\(esc)]10;rgb:f/8/0\(bel)")
        #expect(reply?.color == TerminalRGB(r: 255, g: 136, b: 0))
        #expect(reply?.target == .foreground)
    }

    @Test("3-digit channels scale by 255/4095")
    func threeDigit() {
        let reply = OSCColorReply.parse("\(esc)]11;rgb:fff/000/800\(bel)")
        #expect(reply?.color == TerminalRGB(r: 255, g: 0, b: 128))
    }

    @Test("mixed channel widths are accepted")
    func mixedWidths() {
        let reply = OSCColorReply.parse("\(esc)]11;rgb:ffff/80/0\(bel)")
        #expect(reply?.color == TerminalRGB(r: 255, g: 128, b: 0))
    }

    @Test("uppercase hex digits")
    func uppercase() {
        let reply = OSCColorReply.parse("\(esc)]11;rgb:ABCD/8080/0000\(bel)")
        #expect(reply?.color == TerminalRGB(r: 171, g: 128, b: 0))
    }

    @Test("#RRGGBB form")
    func hashForm() {
        let reply = OSCColorReply.parse("\(esc)]11;#1E1E1E\(bel)")
        #expect(reply?.color == TerminalRGB(r: 0x1E, g: 0x1E, b: 0x1E))
        #expect(reply?.target == .background)
    }

    @Test("trailing bytes after the terminator are ignored")
    func trailingDeviceAttributes() {
        let reply = OSCColorReply.parse("\(esc)]11;rgb:0000/2b2b/3636\(esc)\\\(esc)[?62;4c")
        #expect(reply?.color == TerminalRGB(r: 0, g: 0x2B, b: 0x36))
    }

    @Test("a foreground reply followed by a background reply yields the first")
    func firstReplyWins() {
        let reply = OSCColorReply.parse("\(esc)]10;rgb:ff/ff/ff\(bel)\(esc)]11;rgb:00/00/00\(bel)")
        #expect(reply?.target == .foreground)
        #expect(reply?.color == TerminalRGB(r: 255, g: 255, b: 255))
    }

    @Test("malformed input returns nil", arguments: [
        "",
        "garbage",
        "\u{1B}]11;rgb:ff/80/00",              // truncated: no terminator
        "\u{1B}]11;rgb:ff/80\u{07}",           // two channels
        "\u{1B}]11;rgb:ff/80/00/00\u{07}",     // four channels
        "\u{1B}]11;rgb:fffff/80/00\u{07}",     // five digits
        "\u{1B}]11;rgb:/80/00\u{07}",          // empty channel
        "\u{1B}]11;rgb:gg/80/00\u{07}",        // non-hex
        "\u{1B}]11;rgb:-f/80/00\u{07}",        // sign is not a hex digit
        "\u{1B}]11;rgb:+f/80/00\u{07}",
        "\u{1B}]11;#12345\u{07}",              // short hash form
        "\u{1B}]11;#1234567\u{07}",            // long hash form
        "\u{1B}]11;#GGGGGG\u{07}",
        "\u{1B}]12;rgb:ff/80/00\u{07}",        // not OSC 10 or 11
        "\u{1B}]11;?\u{07}",                   // the query itself
        "\u{1B}]11;rgb:ff/80/00\u{1B}",        // ESC with no backslash
        "rgb:ff/80/00",                        // no envelope
    ])
    func malformed(input: String) {
        #expect(OSCColorReply.parse(input) == nil)
    }
}
