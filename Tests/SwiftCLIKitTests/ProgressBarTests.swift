// ProgressBarTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ProgressBar")
struct ProgressBarTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Golden path: 30% progress shows percentage text")
    func goldenPath() {
        var frame = makeFrame(width: 30, height: 1)
        let bar = ProgressBar(current: 3, total: 10, showPercentage: true)
        bar.render(into: &frame)
        let buf = frame.cellBuffer
        let row = (0..<30).map { buf[$0, 0].character }
        let rowString = String(row)
        #expect(rowString.contains("30%"))
    }

    @Test("Zero total does not crash (division safety)")
    func zeroTotal() {
        var frame = makeFrame(width: 20, height: 1)
        let bar = ProgressBar(current: 5, total: 0)
        bar.render(into: &frame)
        // Just verify no crash occurred
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == buf[0, 0].character) // trivially true
    }

    @Test("Complete progress shows 100%")
    func complete() {
        var frame = makeFrame(width: 30, height: 1)
        let bar = ProgressBar(current: 10, total: 10, showPercentage: true)
        bar.render(into: &frame)
        let buf = frame.cellBuffer
        let row = (0..<30).map { buf[$0, 0].character }
        let rowString = String(row)
        #expect(rowString.contains("100%"))
    }
}
