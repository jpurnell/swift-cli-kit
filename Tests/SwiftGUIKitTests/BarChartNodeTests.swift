// BarChartNodeTests.swift
// SwiftGUIKit
// Phase 1 — BarChart: node structural + token→node→cell parity (RED first).

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("BarChart.node")
struct BarChartNodeTests {

    @Test("node() drops per-bar styles, keeping label/value + a single color role")
    func nodeDefaults() {
        let chart = BarChart(bars: [.init(label: "A", value: 10), .init(label: "B", value: 20)])
        #expect(chart.node() == .barChart(
            bars: [BarValue(label: "A", value: 10), BarValue(label: "B", value: 20)],
            barWidth: 3, barGap: 1, max: nil, showValues: false, color: .accent))
    }

    @Test("node() carries layout params and a chosen color role")
    func nodeCustom() {
        let chart = BarChart(bars: [.init(label: "X", value: 5)], barWidth: 2, barGap: 0, max: 8, showValues: true)
        #expect(chart.node(color: .success) == .barChart(
            bars: [BarValue(label: "X", value: 5)],
            barWidth: 2, barGap: 0, max: 8, showValues: true, color: .success))
    }
}

@Suite("BarChart parity (token→node→cell == legacy)")
struct BarChartParityTests {

    private let resolver = TerminalTokenResolver(theme: .dark)
    private let ctx = DesignContext.terminalTruecolor

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func tokenStyle(_ role: ColorRole) -> CellStyle {
        let r = resolver.color(role, in: ctx)
        return CellStyle(fg: r.color, bg: .default, attributes: r.attributes)
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height {
            for x in 0..<width where a[x, y] != b[x, y] { return false }
        }
        return true
    }

    @Test("parity across bars × layout × showValues × width × height, incl. all-zero & tall")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let role = ColorRole.accent
        let style = tokenStyle(role)

        let datasets: [[(String, Double)]] = [
            [],
            [("A", 10)],
            [("A", 10), ("B", 20), ("C", 15)],
            [("A", 0), ("B", 0)],           // all-zero → labels-only branch
            [("aa", 3), ("bb", 9), ("cc", 1)],
        ]
        for data in datasets {
            for barWidth in [1, 3] {
                for barGap in [0, 1] {
                    for showValues in [false, true] {
                        for max in [Double?.none, 20.0] {
                            for (width, height) in [(5, 1), (20, 3), (40, 5)] {
                                let chart = BarChart(
                                    bars: data.map { BarChart.Bar(label: $0.0, value: $0.1, style: style) },
                                    barWidth: barWidth, barGap: barGap, max: max, showValues: showValues)

                                var legacyFrame = makeFrame(width: width, height: height)
                                chart.render(into: &legacyFrame)

                                var nodeFrame = makeFrame(width: width, height: height)
                                renderer.render(chart.node(color: role), into: &nodeFrame)

                                #expect(gridsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: width, height: height),
                                        "mismatch data=\(data) bw=\(barWidth) gap=\(barGap) vals=\(showValues) max=\(String(describing: max)) \(width)x\(height)")
                            }
                        }
                    }
                }
            }
        }
    }
}
