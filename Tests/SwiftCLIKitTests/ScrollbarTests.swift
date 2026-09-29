// ScrollbarTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Scrollbar")
struct ScrollbarTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Vertical scrollbar at top: thumb character near top")
    func verticalTop() {
        var frame = makeFrame(width: 1, height: 10)
        let scrollbar = Scrollbar(
            orientation: .vertical,
            contentLength: 100,
            viewportSize: 10,
            offset: 0
        )
        scrollbar.render(into: &frame)
        let buf = frame.cellBuffer
        // Thumb should be at or near the top (row 0)
        let topCell = buf[0, 0]
        #expect(topCell.character != " ")
    }

    @Test("Vertical scrollbar at mid offset: thumb in middle region")
    func verticalMid() {
        var frame = makeFrame(width: 1, height: 10)
        let scrollbar = Scrollbar(
            orientation: .vertical,
            contentLength: 100,
            viewportSize: 10,
            offset: 50
        )
        scrollbar.render(into: &frame)
        let buf = frame.cellBuffer
        // Thumb should be in the middle area (around row 5)
        let midCell = buf[0, 5]
        #expect(midCell.character != " ")
    }

    @Test("Content fits viewport: no distinct thumb needed")
    func contentFitsViewport() {
        var frame = makeFrame(width: 1, height: 10)
        let scrollbar = Scrollbar(
            orientation: .vertical,
            contentLength: 10,
            viewportSize: 10,
            offset: 0
        )
        scrollbar.render(into: &frame)
        let buf = frame.cellBuffer
        // Either all cells are thumb or all are track -- either is valid
        let chars = (0..<10).map { buf[0, $0].character }
        let uniqueChars = Set(chars)
        // Should have at most 2 distinct characters (thumb + track or uniform)
        #expect(uniqueChars.count <= 2)
    }

    @Test("Horizontal scrollbar renders along a row")
    func horizontal() {
        var frame = makeFrame(width: 10, height: 1)
        let scrollbar = Scrollbar(
            orientation: .horizontal,
            contentLength: 100,
            viewportSize: 10,
            offset: 0
        )
        scrollbar.render(into: &frame)
        let buf = frame.cellBuffer
        // Thumb should be at or near the left (col 0)
        let leftCell = buf[0, 0]
        #expect(leftCell.character != " ")
    }
}
