// FrameTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Frame")
struct FrameTests {

    @Test("Writing outside the frame rect is clipped")
    func clipping() {
        let buf = CellBuffer(width: 20, height: 20)
        var frame = Frame(buffer: buf, rect: Rect(x: 5, y: 5, width: 10, height: 10))
        // Write at relative position that maps outside the buffer
        frame.setCell(x: 15, y: 15, cell: Cell(character: "X"))
        // The cell should not appear in the buffer (clipped)
        let result = frame.cellBuffer
        #expect(result[20, 20] == .empty)
    }

    @Test("Writing inside the frame rect updates the correct buffer position")
    func validWrite() {
        let buf = CellBuffer(width: 20, height: 20)
        var frame = Frame(buffer: buf, rect: Rect(x: 5, y: 5, width: 10, height: 10))
        let cell = Cell(character: "A", fg: .ansi8(.green))
        frame.setCell(x: 2, y: 3, cell: cell)
        let result = frame.cellBuffer
        // Relative (2,3) inside rect at (5,5) → absolute (7,8)
        #expect(result[7, 8] == cell)
    }

    @Test("Sub-frame clips to intersection of parent and child rects")
    func subFrame() {
        let buf = CellBuffer(width: 20, height: 20)
        let frame = Frame(buffer: buf, rect: Rect(x: 5, y: 5, width: 10, height: 10))
        let sub = frame.subFrame(Rect(x: 8, y: 8, width: 20, height: 20))
        // Sub-frame rect should be clipped to parent: intersection of (5,5,10,10) and (8,8,20,20)
        #expect(sub.rect == Rect(x: 8, y: 8, width: 7, height: 7))
    }

    @Test("writeText past right edge is truncated")
    func writeText() {
        let buf = CellBuffer(width: 10, height: 1)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: 10, height: 1))
        frame.writeText("hello world!", x: 7, y: 0)
        let result = frame.cellBuffer
        // Only "hel" should fit at positions 7,8,9
        #expect(result[7, 0].character == "h")
        #expect(result[8, 0].character == "e")
        #expect(result[9, 0].character == "l")
    }
}
