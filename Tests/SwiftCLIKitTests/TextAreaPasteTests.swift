// TextAreaPasteTests.swift
// SwiftCLIKit

import Testing
@testable import SwiftCLIKit

/// A bracketed paste reaches a ``TextArea`` as one `Key.paste`; it used to fall through to
/// `.unhandled`, so pasting into a multi-line field did nothing.
@Suite("TextArea paste")
struct TextAreaPasteTests {

    @Test("A paste is inserted at the cursor, and the cursor lands after it")
    func insertsAtCursor() {
        var area = TextArea(text: "Hello world")
        area.cursorCol = 6
        #expect(area.handleKey(.paste("big ")) == .changed("Hello big world"))
        #expect(area.cursorRow == 0)
        #expect(area.cursorCol == 10)
    }

    @Test("Line breaks in a paste become lines, whichever convention the terminal sent")
    func lineBreaksBecomeLines() {
        // Terminals usually send CR for a pasted newline; files carry LF or CRLF.
        var area = TextArea(text: "ab")
        area.cursorCol = 1
        #expect(area.handleKey(.paste("1\r2\n3\r\n4")) == .changed("a1\n2\n3\n4b"))
        #expect(area.lines == ["a1", "2", "3", "4b"])
        #expect(area.cursorRow == 3)
        #expect(area.cursorCol == 1)
    }

    @Test("A paste of Unicode arrives whole")
    func unicodeWhole() {
        var area = TextArea()
        let pasted = "caf\u{E9} \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} \u{4E2D}\u{6587}"
        #expect(area.handleKey(.paste(pasted)) == .changed(pasted))
        #expect(area.cursorCol == pasted.count)
    }

    @Test("An empty paste changes nothing")
    func emptyPaste() {
        var area = TextArea(text: "x")
        #expect(area.handleKey(.paste("")) == .unhandled)
        #expect(area.text == "x")
    }
}
