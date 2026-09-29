// DiffRendererTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("DiffRenderer")
struct DiffRendererTests {

    @Test("Identical buffers produce empty or minimal output")
    func identicalBuffers() {
        var renderer = DiffRenderer()
        let buf = CellBuffer(width: 10, height: 5)
        let output = renderer.render(current: buf, previous: buf)
        #expect(output.isEmpty)
    }

    @Test("Single cell change produces output with cursor positioning")
    func singleCellChange() {
        var renderer = DiffRenderer()
        var current = CellBuffer(width: 10, height: 5)
        let previous = CellBuffer(width: 10, height: 5)
        current[3, 2] = Cell(character: "X", fg: .ansi8(.red))
        let output = renderer.render(current: current, previous: previous)
        // Should contain escape sequences for cursor move and the character
        #expect(output.contains("X"))
    }

    @Test("Nil previous buffer produces full redraw with all non-empty cells")
    func fullChangeNilPrevious() {
        var renderer = DiffRenderer()
        var current = CellBuffer(width: 5, height: 1)
        current[0, 0] = Cell(character: "A")
        current[2, 0] = Cell(character: "B")
        let output = renderer.render(current: current, previous: nil)
        #expect(output.contains("A"))
        #expect(output.contains("B"))
    }

    @Test("Style-only change emits SGR escape sequence")
    func styleOnlyChange() {
        var renderer = DiffRenderer()
        var current = CellBuffer(width: 5, height: 1)
        var previous = CellBuffer(width: 5, height: 1)
        previous[1, 0] = Cell(character: "Z", fg: .ansi8(.white))
        current[1, 0] = Cell(character: "Z", fg: .ansi8(.red))
        let output = renderer.render(current: current, previous: previous)
        // Should contain SGR codes (escape + "[" + color codes)
        #expect(output.contains("\u{1B}["))
    }

    @Test("Adjacent horizontal changes avoid redundant cursor moves")
    func adjacentChanges() {
        var renderer = DiffRenderer()
        var current = CellBuffer(width: 10, height: 1)
        let previous = CellBuffer(width: 10, height: 1)
        current[3, 0] = Cell(character: "A")
        current[4, 0] = Cell(character: "B")
        let output = renderer.render(current: current, previous: previous)
        #expect(output.contains("A"))
        #expect(output.contains("B"))
        // Count cursor-position sequences (ESC[...H), not all ESC[ sequences
        // which also include style SGR (ESC[...m) and the trailing reset.
        var moveCount = 0
        var searchStart = output.startIndex
        while let escRange = output.range(of: "\u{1B}[", range: searchStart..<output.endIndex) {
            let afterEsc = escRange.upperBound
            if let hIndex = output[afterEsc...].firstIndex(where: { $0 == "H" || $0 == "m" }) {
                if output[hIndex] == "H" { moveCount += 1 }
                searchStart = output.index(after: hIndex)
            } else {
                break
            }
        }
        #expect(moveCount == 1, "Adjacent cells should need only one cursor move, got \(moveCount)")
    }

    @Test("Empty current buffer with nil previous produces empty output")
    func emptyBuffer() {
        var renderer = DiffRenderer()
        let current = CellBuffer(width: 5, height: 5)
        let output = renderer.render(current: current, previous: nil)
        #expect(output.isEmpty)
    }

    @Test("Same-style character change avoids redundant style reset and reapply")
    func escapeEfficiency() {
        var renderer = DiffRenderer()
        var previous = CellBuffer(width: 10, height: 1)
        var current = CellBuffer(width: 10, height: 1)
        // Both cells share the same style (red foreground), only the character differs
        previous[5, 0] = Cell(character: "A", fg: .ansi8(.red))
        current[5, 0] = Cell(character: "B", fg: .ansi8(.red))
        let output = renderer.render(current: current, previous: previous)
        // The output should contain "B" (the changed character)
        #expect(output.contains("B"))
        // Since only one cell changed and needs one cursor move + one style + one char,
        // the output should be reasonably short — not a full redraw
        #expect(output.count < 50, "Output should be compact: cursor move + style + char, got \(output.count) chars")
    }
}
