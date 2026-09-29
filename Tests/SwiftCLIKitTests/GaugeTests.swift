// GaugeTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Gauge")
struct GaugeTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Half-full gauge fills exactly half the width")
    func halfFull() {
        var frame = makeFrame(width: 20, height: 1)
        let gauge = Gauge(ratio: 0.5)
        gauge.render(into: &frame)
        let buf = frame.cellBuffer
        // First 10 cells should be filled char, last 10 unfilled
        let filledCount = (0..<20).filter { buf[$0, 0].character == "█" }.count
        #expect(filledCount == 10)
    }

    @Test("Empty gauge has all unfilled characters")
    func empty() {
        var frame = makeFrame(width: 20, height: 1)
        let gauge = Gauge(ratio: 0.0)
        gauge.render(into: &frame)
        let buf = frame.cellBuffer
        let filledCount = (0..<20).filter { buf[$0, 0].character == "█" }.count
        #expect(filledCount == 0)
    }

    @Test("Full gauge has all filled characters")
    func full() {
        var frame = makeFrame(width: 20, height: 1)
        let gauge = Gauge(ratio: 1.0)
        gauge.render(into: &frame)
        let buf = frame.cellBuffer
        let filledCount = (0..<20).filter { buf[$0, 0].character == "█" }.count
        #expect(filledCount == 20)
    }

    @Test("Label is rendered centered on the gauge")
    func withLabel() {
        var frame = makeFrame(width: 20, height: 1)
        let gauge = Gauge(ratio: 0.75, label: "75%")
        gauge.render(into: &frame)
        let buf = frame.cellBuffer
        let row = (0..<20).map { buf[$0, 0].character }
        let rowString = String(row)
        #expect(rowString.contains("75%"))
    }
}
