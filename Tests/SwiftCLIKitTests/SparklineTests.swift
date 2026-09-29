// SparklineTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Sparkline")
struct SparklineTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Golden path: data points produce non-empty cells")
    func goldenPath() {
        var frame = makeFrame(width: 5, height: 3)
        let spark = Sparkline(data: [1.0, 3.0, 2.0, 5.0, 4.0])
        spark.render(into: &frame)
        let buf = frame.cellBuffer
        // At least some cells should be non-space after rendering
        let nonEmpty = (0..<5).flatMap { x in (0..<3).map { y in buf[x, y] } }
            .filter { $0.character != " " }
        #expect(nonEmpty.count > 0)
    }

    @Test("Empty data does not crash")
    func emptyData() {
        var frame = makeFrame(width: 10, height: 3)
        let spark = Sparkline(data: [])
        spark.render(into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == " ")
    }

    @Test("Single data point fills one column")
    func singlePoint() {
        var frame = makeFrame(width: 5, height: 3)
        let spark = Sparkline(data: [5.0])
        spark.render(into: &frame)
        let buf = frame.cellBuffer
        // Column 0 should have at least one non-space cell
        let col0 = (0..<3).map { buf[0, $0].character }
        let hasContent = col0.contains(where: { $0 != " " })
        #expect(hasContent)
    }
}
