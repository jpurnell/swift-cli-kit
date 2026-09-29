// CellBufferTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("CellBuffer")
struct CellBufferTests {

    @Test("Write a cell and read it back at the same position")
    func writeReadRoundTrip() {
        var buf = CellBuffer(width: 10, height: 10)
        let cell = Cell(character: "A", fg: .ansi8(.red), bg: .ansi8(.blue), attributes: [.bold])
        buf[3, 5] = cell
        #expect(buf[3, 5] == cell)
    }

    @Test("Fill a rectangular region and verify all cells match")
    func fillRegion() {
        var buf = CellBuffer(width: 10, height: 10)
        let cell = Cell(character: "#", fg: .ansi8(.green), attributes: [.underline])
        let rect = Rect(x: 1, y: 1, width: 3, height: 2)
        buf.fill(rect, with: cell)
        for y in 1...2 {
            for x in 1...3 {
                #expect(buf[x, y] == cell, "Cell at (\(x), \(y)) should be filled")
            }
        }
    }

    @Test("Out-of-bounds write does not crash and leaves buffer unchanged")
    func outOfBoundsWrite() {
        var buf = CellBuffer(width: 5, height: 5)
        let cell = Cell(character: "X")
        buf[-1, 0] = cell
        buf[6, 0] = cell
        buf[0, -1] = cell
        buf[0, 6] = cell
        // All valid cells should still be empty
        for y in 0..<5 {
            for x in 0..<5 {
                #expect(buf[x, y] == .empty)
            }
        }
    }

    @Test("Out-of-bounds read returns Cell.empty")
    func outOfBoundsRead() {
        let buf = CellBuffer(width: 5, height: 5)
        #expect(buf[-1, -1] == .empty)
        #expect(buf[10, 10] == .empty)
    }

    @Test("writeText places individual characters sequentially")
    func writeText() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.writeText("hello", at: (x: 2, y: 0), fg: .ansi8(.white))
        let expected: [Character] = ["h", "e", "l", "l", "o"]
        for (i, ch) in expected.enumerated() {
            #expect(buf[2 + i, 0].character == ch, "Character at position \(2 + i) should be '\(ch)'")
        }
    }

    @Test("writeText clips when string extends past buffer width")
    func writeTextClipping() {
        var buf = CellBuffer(width: 5, height: 1)
        buf.writeText("hello world", at: (x: 2, y: 0))
        // Should write "hel" at positions 2,3,4 and not crash
        #expect(buf[2, 0].character == "h")
        #expect(buf[3, 0].character == "e")
        #expect(buf[4, 0].character == "l")
    }

    @Test("Clear resets all cells to empty")
    func clear() {
        var buf = CellBuffer(width: 3, height: 3)
        buf[1, 1] = Cell(character: "X", fg: .ansi8(.red))
        buf.clear()
        for y in 0..<3 {
            for x in 0..<3 {
                #expect(buf[x, y] == .empty)
            }
        }
    }
}
