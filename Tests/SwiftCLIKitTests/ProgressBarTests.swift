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

@Suite("ProgressBarLayout")
struct ProgressBarLayoutTests {

    @Test("NaN current resolves to the zero-total fallback instead of trapping")
    func nanCurrent() {
        let layout = ProgressBarLayout(current: .nan, total: 10, showPercentage: true)
        #expect(layout.content == .zeroTotal(label: "0%"))
    }

    @Test("Infinite current over infinite total (NaN ratio) resolves to the fallback")
    func infiniteOverInfinite() {
        let layout = ProgressBarLayout(current: .infinity, total: .infinity, showPercentage: true)
        #expect(layout.content == .zeroTotal(label: "0%"))
    }

    @Test("NaN ratio without a percentage label carries no label")
    func nanWithoutPercentage() {
        let layout = ProgressBarLayout(current: .nan, total: 10, showPercentage: false)
        #expect(layout.content == .zeroTotal(label: nil))
    }

    @Test("Infinite current over a finite total clamps to a full bar")
    func infiniteCurrent() {
        let layout = ProgressBarLayout(current: .infinity, total: 10, showPercentage: true)
        #expect(layout.content == .bar(ratio: 1.0, label: "100%"))
    }

    @Test("Finite current over an infinite total is an empty bar")
    func infiniteTotal() {
        let layout = ProgressBarLayout(current: 5, total: .infinity, showPercentage: true)
        #expect(layout.content == .bar(ratio: 0.0, label: "0%"))
    }

    @Test("NaN total resolves to the zero-total fallback")
    func nanTotal() {
        let layout = ProgressBarLayout(current: 5, total: .nan, showPercentage: true)
        #expect(layout.content == .zeroTotal(label: "0%"))
    }

    @Test("Negative progress clamps to an empty bar")
    func negativeCurrent() {
        let layout = ProgressBarLayout(current: -3, total: 10, showPercentage: true)
        #expect(layout.content == .bar(ratio: 0.0, label: "0%"))
    }

    @Test("Rendering a NaN progress bar does not trap")
    func renderNaN() {
        let buf = CellBuffer(width: 20, height: 1)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: 20, height: 1))
        ProgressBar(current: .nan, total: 10, showPercentage: true).render(into: &frame)
        let row = String((0..<20).map { frame.cellBuffer[$0, 0].character })
        #expect(row.hasPrefix("0%"))
    }
}
