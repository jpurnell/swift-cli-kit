// BlockTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Block")
struct BlockTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("All borders render corners and edges in the buffer")
    func allBorders() {
        var frame = makeFrame(width: 20, height: 10)
        let block = Block(borders: .all, boxDrawing: .unicode)
        _ = block.render(into: &frame)
        let buf = frame.cellBuffer
        // Top-left corner should be the unicode box-drawing character
        #expect(buf[0, 0].character == Character("\u{250C}"))
        // Top-right corner
        #expect(buf[19, 0].character == Character("\u{2510}"))
        // Bottom-left corner
        #expect(buf[0, 9].character == Character("\u{2514}"))
        // Bottom-right corner
        #expect(buf[19, 9].character == Character("\u{2518}"))
    }

    @Test("Title appears in the top border")
    func titleRendering() {
        var frame = makeFrame(width: 20, height: 10)
        let block = Block(title: "Test", borders: .all, boxDrawing: .unicode)
        _ = block.render(into: &frame)
        let buf = frame.cellBuffer
        // Title "Test" should appear somewhere in row 0 after the top-left corner
        let topRow = (0..<20).map { buf[$0, 0].character }
        let topString = String(topRow)
        #expect(topString.contains("Test"))
    }

    @Test("Inner frame dimensions are reduced by border size")
    func innerFrameDimensions() {
        var frame = makeFrame(width: 20, height: 10)
        let block = Block(borders: .all)
        let inner = block.render(into: &frame)
        // All borders: 1 cell each side → inner 18x8
        #expect(inner.rect.width == 18)
        #expect(inner.rect.height == 8)
    }

    @Test("Partial borders only reduce dimensions for present sides")
    func partialBorders() {
        var frame = makeFrame(width: 20, height: 10)
        let block = Block(borders: [.top, .bottom])
        let inner = block.render(into: &frame)
        // Top and bottom only → inner width = 20, height = 8
        #expect(inner.rect.width == 20)
        #expect(inner.rect.height == 8)
    }

    @Test("Centered title is centered in the top border")
    func titleAlignment() {
        var frame = makeFrame(width: 20, height: 5)
        let block = Block(title: "Hi", borders: .all, titleAlignment: .center)
        _ = block.render(into: &frame)
        let buf = frame.cellBuffer
        // "Hi" centered in 18 inner chars → offset ~9 from left corner
        // Position 9 and 10 in the top row (after corner at 0)
        let topRow = (1..<19).map { buf[$0, 0].character }
        let topString = String(topRow)
        #expect(topString.contains("Hi"))
        // Check centering: find "H" position
        if let hIdx = topRow.firstIndex(of: "H") {
            let pos = topRow.distance(from: topRow.startIndex, to: hIdx)
            // Should be roughly centered (around position 8 in 18-char span)
            #expect(pos >= 7 && pos <= 9, "Title should be approximately centered")
        }
    }

    @Test("ASCII box drawing uses +, -, | characters")
    func asciiFallback() {
        var frame = makeFrame(width: 10, height: 5)
        let block = Block(borders: .all, boxDrawing: .ascii)
        _ = block.render(into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == "+")
        #expect(buf[1, 0].character == "-")
        #expect(buf[0, 1].character == "|")
    }
}
