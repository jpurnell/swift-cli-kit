// SparklineNodeTests.swift
// SwiftGUIKit
// Phase 1 — Sparkline: node structural + token→node→cell parity (RED first).

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Sparkline.node")
struct SparklineNodeTests {

    @Test("node() carries raw data/max with default color role")
    func nodeDefaults() {
        let node = Sparkline(data: [1, 3, 2, 5, 4]).node()
        #expect(node == .sparkline(data: [1, 3, 2, 5, 4], max: nil, color: .accent))
    }

    @Test("node() passes explicit max and chosen color role through")
    func nodeCustom() {
        let node = Sparkline(data: [2, 4], max: 8).node(color: .success)
        #expect(node == .sparkline(data: [2, 4], max: 8, color: .success))
    }
}

@Suite("Sparkline parity (token→node→cell == legacy)")
struct SparklineParityTests {

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

    @Test("parity across data × max × width × height (multi-row), incl. empty & zero data")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let role = ColorRole.accent
        let style = tokenStyle(role)

        let datasets: [[Double]] = [[], [5], [1, 3, 2, 5, 4], [0, 0, 0], [10, 5, 1], [3, 3, 3]]
        for data in datasets {
            for max in [Double?.none, 5.0, 10.0] {
                for width in [1, 5, 40] {
                    for height in [1, 3] {
                        var legacyFrame = makeFrame(width: width, height: height)
                        Sparkline(data: data, style: style, max: max).render(into: &legacyFrame)

                        var nodeFrame = makeFrame(width: width, height: height)
                        renderer.render(Sparkline(data: data, max: max).node(color: role), into: &nodeFrame)

                        #expect(gridsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: width, height: height),
                                "mismatch data=\(data) max=\(String(describing: max)) w=\(width) h=\(height)")
                    }
                }
            }
        }
    }
}
