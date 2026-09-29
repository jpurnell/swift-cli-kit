// ParagraphTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Paragraph")
struct ParagraphTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Word wrap splits long text across multiple lines")
    func wordWrap() {
        var frame = makeFrame(width: 20, height: 5)
        let para = Paragraph(text: "The quick brown fox jumps over", wrap: true)
        para.render(into: &frame)
        let buf = frame.cellBuffer
        // Second line should have content (text wraps)
        let secondLineHasContent = (0..<20).contains { buf[$0, 1].character != " " }
        #expect(secondLineHasContent, "Long text should wrap to second line")
    }

    @Test("No-wrap mode truncates long lines")
    func noWrap() {
        var frame = makeFrame(width: 10, height: 1)
        let para = Paragraph(text: "This is a very long line", wrap: false)
        para.render(into: &frame)
        let buf = frame.cellBuffer
        // Only first 10 characters should appear
        #expect(buf[0, 0].character == "T")
        #expect(buf[9, 0].character == "v")
    }

    @Test("Left alignment has no leading spaces")
    func leftAlign() {
        var frame = makeFrame(width: 20, height: 1)
        let para = Paragraph(text: "Hi", alignment: .left)
        para.render(into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == "H")
        #expect(buf[1, 0].character == "i")
    }

    @Test("Center alignment pads with spaces on both sides")
    func centerAlign() {
        var frame = makeFrame(width: 20, height: 1)
        let para = Paragraph(text: "Hi", alignment: .center)
        para.render(into: &frame)
        let buf = frame.cellBuffer
        // "Hi" is 2 chars in 20 cols → 9 leading spaces
        #expect(buf[9, 0].character == "H")
        #expect(buf[10, 0].character == "i")
    }

    @Test("Right alignment right-justifies the text")
    func rightAlign() {
        var frame = makeFrame(width: 20, height: 1)
        let para = Paragraph(text: "Hi", alignment: .right)
        para.render(into: &frame)
        let buf = frame.cellBuffer
        // "Hi" right-justified in 20 cols → starts at 18
        #expect(buf[18, 0].character == "H")
        #expect(buf[19, 0].character == "i")
    }

    @Test("Empty text does not crash")
    func emptyText() {
        var frame = makeFrame(width: 10, height: 3)
        let para = Paragraph(text: "")
        para.render(into: &frame)
        let buf = frame.cellBuffer
        // All cells should be empty
        for y in 0..<3 {
            for x in 0..<10 {
                #expect(buf[x, y] == .empty)
            }
        }
    }

    @Test("Multi-word text wraps correctly across lines")
    func multiLine() {
        var frame = makeFrame(width: 10, height: 5)
        let para = Paragraph(text: "one two three four five", wrap: true)
        para.render(into: &frame)
        let buf = frame.cellBuffer
        // "one two" fits in 10; "three four" on next line; "five" on third
        #expect(buf[0, 0].character == "o")
        let thirdLineHasContent = (0..<10).contains { buf[$0, 2].character != " " }
        #expect(thirdLineHasContent, "Text should span at least 3 lines")
    }

    @Test("Forced line break via newline character is respected in wrap and no-wrap modes")
    func forcedLineBreak() {
        // Wrap mode: \n should force a line break
        var wrapFrame = makeFrame(width: 40, height: 5)
        let wrapPara = Paragraph(text: "line one\nline two", wrap: true)
        wrapPara.render(into: &wrapFrame)
        let wrapBuf = wrapFrame.cellBuffer
        // Row 0 should contain "line"
        let row0Wrap = (0..<40).map { wrapBuf[$0, 0].character }
        #expect(String(row0Wrap).contains("line"), "Row 0 should contain text from first line")
        // Row 1 should contain "line" (from "line two")
        let row1Wrap = (0..<40).map { wrapBuf[$0, 1].character }
        #expect(String(row1Wrap).contains("line"), "Row 1 should contain text from second line after \\n")

        // No-wrap mode: \n should still be respected as a line break
        var noWrapFrame = makeFrame(width: 40, height: 5)
        let noWrapPara = Paragraph(text: "line one\nline two", wrap: false)
        noWrapPara.render(into: &noWrapFrame)
        let noWrapBuf = noWrapFrame.cellBuffer
        let row0NoWrap = (0..<40).map { noWrapBuf[$0, 0].character }
        #expect(String(row0NoWrap).contains("line"), "Row 0 should contain text (no-wrap mode)")
        let row1NoWrap = (0..<40).map { noWrapBuf[$0, 1].character }
        #expect(String(row1NoWrap).contains("line"), "Row 1 should contain text after \\n (no-wrap mode)")
    }
}
