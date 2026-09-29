// ParagraphSourceTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-07-03.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Paragraph source retention")
struct ParagraphSourceTests {

    @Test("logicalLines splits only on explicit newlines, preserving pre-wrap text")
    func logicalLines() {
        let para = Paragraph(text: "line one\nline two")
        #expect(para.logicalLines == ["line one", "line two"])
    }

    @Test("logicalLines of a single unwrapped paragraph is one entry")
    func logicalLinesSingle() {
        let para = Paragraph(text: "The quick brown fox jumps over the lazy dog")
        #expect(para.logicalLines == ["The quick brown fox jumps over the lazy dog"])
    }

    @Test("logicalLines of empty text is empty")
    func logicalLinesEmpty() {
        let para = Paragraph(text: "")
        #expect(para.logicalLines == [])
    }

    @Test("wrappedLines splits a long logical line into multiple visual lines")
    func wrappedLines() {
        let para = Paragraph(text: "one two three four five", wrap: true)
        let lines = para.wrappedLines(width: 10)
        // "one two" (7) fits; "three four" (10) fits; "five" on its own
        #expect(lines.count >= 3)
        #expect(lines[0] == "one two")
    }

    @Test("sourceLineMap maps every visual line back to its logical line index")
    func sourceLineMap() {
        // Two logical lines; the first wraps across several visual rows.
        let para = Paragraph(text: "one two three four five\nsecond", wrap: true)
        let map = para.sourceLineMap(width: 10)
        let lines = para.wrappedLines(width: 10)
        #expect(map.count == lines.count)
        // Every visual row for the wrapped first line maps to source 0.
        #expect(map.first == 0)
        // The final visual row is the second logical line.
        #expect(map.last == 1)
    }

    @Test("wrappedLines is consistent with the rendered frame content")
    func wrappedMatchesRender() {
        let para = Paragraph(text: "alpha beta gamma delta epsilon", wrap: true)
        let width = 12
        let lines = para.wrappedLines(width: width)

        let buf = CellBuffer(width: width, height: 10)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: 10))
        para.render(into: &frame)
        let rendered = frame.cellBuffer

        for (row, line) in lines.enumerated() {
            let rowChars = (0..<width).map { rendered[$0, row].character }
            let rowText = String(rowChars).trimmingCharacters(in: .whitespaces)
            #expect(rowText == line, "Rendered row \(row) should match wrappedLines[\(row)]")
        }
    }
}
