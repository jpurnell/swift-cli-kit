// NonFiniteInputTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-24.
//
// Every public entry point here used to convert a floating-point value to `Int`
// without first showing it was representable, so a NaN, an infinity or a value
// beyond `Int`'s range stopped the process. These tests pin what each one does
// instead. Finite, in-range behaviour is covered by each widget's own suite.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Non-finite and out-of-range inputs")
struct NonFiniteInputTests {

    // MARK: - TerminalFormatter

    @Test("formatNumber of NaN in a narrow column does not trap")
    func formatNumberNaNNarrow() {
        #expect(TerminalFormatter.formatNumber(.nan, locale: "en", maxWidth: 2) == "na")
    }

    @Test("formatNumber of infinity in a narrow column does not trap")
    func formatNumberInfinityNarrow() {
        #expect(TerminalFormatter.formatNumber(-.infinity, locale: "en", maxWidth: 1) == "-")
    }

    @Test("formatNumber of a value beyond Int's range does not trap")
    func formatNumberHuge() {
        #expect(TerminalFormatter.formatNumber(1e300, locale: "en", maxWidth: 6) == "1e+300")
    }

    @Test("formatNumber still uses compact notation inside Int's range")
    func formatNumberCompactUnchanged() {
        #expect(TerminalFormatter.formatNumber(1_234_567.89, locale: "en", maxWidth: 5) == "1.2M")
        #expect(TerminalFormatter.formatNumber(-98_765, locale: "en", maxWidth: 5) == "-98K")
        #expect(TerminalFormatter.formatNumber(5e18, locale: "en", maxWidth: 10) == "5000000.0T")
    }

    // MARK: - Formatting

    @Test("elapsed saturates for infinity instead of trapping")
    func elapsedInfinity() {
        #expect(Formatting.elapsed(.infinity).hasSuffix("m"))
        #expect(Formatting.elapsed(1e300) == Formatting.elapsed(.infinity))
    }

    @Test("elapsed of NaN reads as under a minute")
    func elapsedNaN() {
        #expect(Formatting.elapsed(.nan) == "< 1m")
    }

    @Test("duration of NaN reads as under a second instead of trapping")
    func durationNaN() {
        #expect(Formatting.duration(.nan) == "< 1s")
    }

    @Test("duration saturates for infinity instead of trapping")
    func durationInfinity() {
        #expect(Formatting.duration(.infinity).hasSuffix("s"))
        #expect(Formatting.duration(1e300) == Formatting.duration(.infinity))
    }

    @Test("duration is unchanged for fractional seconds")
    func durationFractionalUnchanged() {
        #expect(Formatting.duration(0.999) == "< 1s")
        #expect(Formatting.duration(1.5) == "1s")
        #expect(Formatting.duration(3723.9) == "1h 2m 3s")
    }

    @Test("rate of NaN and infinity names the value instead of trapping")
    func rateNonFinite() {
        #expect(Formatting.rate(.nan, unit: "req/s") == "nan req/s")
        #expect(Formatting.rate(.infinity, unit: "req/s") == "inf req/s")
    }

    // MARK: - Geometry

    @Test("GaugeGeometry fills nothing for a NaN ratio")
    func gaugeNaN() {
        let geometry = GaugeGeometry(width: 10, ratio: .nan, labelLength: nil)
        #expect(geometry.filledRange == 0..<0)
        #expect(geometry.unfilledRange == 0..<10)
    }

    @Test("GaugeGeometry clamps infinities")
    func gaugeInfinity() {
        #expect(GaugeGeometry(width: 10, ratio: .infinity, labelLength: nil).filledRange == 0..<10)
        #expect(GaugeGeometry(width: 10, ratio: -.infinity, labelLength: nil).filledRange == 0..<0)
    }

    @Test("SparklineGeometry draws a NaN point as an empty column")
    func sparklineNaN() {
        let geometry = SparklineGeometry(data: [4, .nan, 8], max: nil, width: 3, height: 2)
        #expect(geometry.columns.count == 3)
        #expect(geometry.columns[1] == SparklineGeometry.Column(fullBlocks: 0, partialIndex: 0))
        #expect(geometry.columns[2] == SparklineGeometry.Column(fullBlocks: 2, partialIndex: 0))
    }

    @Test("SparklineGeometry scaled by an infinite data maximum draws empty columns, the infinity as a gap")
    func sparklineInfinity() {
        let empty = SparklineGeometry.Column(fullBlocks: 0, partialIndex: 0)
        let geometry = SparklineGeometry(data: [4, .infinity, 8], max: nil, width: 3, height: 2)
        #expect(geometry.columns == [empty, empty, empty])
    }

    @Test("SparklineGeometry keeps its existing answers for a non-finite explicit maximum")
    func sparklineNonFiniteMax() {
        let empty = SparklineGeometry.Column(fullBlocks: 0, partialIndex: 0)
        #expect(SparklineGeometry(data: [1, 2], max: .nan, width: 2, height: 2).columns.isEmpty)
        #expect(SparklineGeometry(data: [1, 2], max: .infinity, width: 2, height: 2).columns == [empty, empty])
    }

    @Test("InlineSparkline draws a NaN point as an empty cell")
    func inlineSparklineNaN() {
        let rendered = InlineSparkline.render(data: [0.0, .nan, 8.0], width: 3, min: 0, max: 8)
        #expect(ANSIStringMetrics.plainText(rendered) == "  \u{2588}")
    }

    @Test("BarChartRenderer draws a NaN bar as empty and labels its value")
    func barChartNaN() {
        let buffer = CellBuffer(width: 12, height: 6)
        var frame = Frame(buffer: buffer, rect: Rect(x: 0, y: 0, width: 12, height: 6))
        BarChartRenderer.draw(
            into: &frame,
            bars: [(label: "A", value: 4), (label: "N", value: .nan), (label: "I", value: .infinity)],
            barWidth: 3,
            barGap: 1,
            max: 4,
            showValues: true,
            style: { _ in CellStyle() }
        )
        let rows = (0..<6).map { y in String((0..<12).map { x in frame.cellBuffer[x, y].character }) }
        let text = rows.joined(separator: "\n")
        #expect(text.contains("nan"))
        #expect(text.contains("inf"))
        // The NaN bar's columns (4...6) carry no bar cells.
        let nanColumnCells = (0..<5).flatMap { y in (4...6).map { x in frame.cellBuffer[x, y].character } }
        #expect(!nanColumnCells.contains("█"))
    }
}
