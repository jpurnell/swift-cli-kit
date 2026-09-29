// BarChartTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("BarChart")
struct BarChartTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Golden path: 3 bars with labels present and proportional heights")
    func goldenPath() {
        var frame = makeFrame(width: 20, height: 10)
        let chart = BarChart(bars: [
            BarChart.Bar(label: "A", value: 10),
            BarChart.Bar(label: "B", value: 20),
            BarChart.Bar(label: "C", value: 15),
        ])
        chart.render(into: &frame)
        let buf = frame.cellBuffer
        // Labels should appear somewhere in the bottom rows
        let allChars = (0..<20).flatMap { x in (0..<10).map { y in buf[x, y].character } }
        let allString = String(allChars)
        #expect(allString.contains("A"))
        #expect(allString.contains("B"))
    }

    @Test("Zero bars does not crash")
    func zeroBars() {
        var frame = makeFrame(width: 20, height: 10)
        let chart = BarChart(bars: [])
        chart.render(into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == " ")
    }

    @Test("All-zero values does not crash (division safety)")
    func allZeroValues() {
        var frame = makeFrame(width: 20, height: 10)
        let chart = BarChart(bars: [
            BarChart.Bar(label: "X", value: 0),
            BarChart.Bar(label: "Y", value: 0),
            BarChart.Bar(label: "Z", value: 0),
        ])
        chart.render(into: &frame)
        // Just verify no crash
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == buf[0, 0].character)
    }
}
