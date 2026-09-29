// ProgressBarNodeTests.swift
// SwiftGUIKit
// Phase 1 — ProgressBar: node structural + token→node→cell parity (RED first).

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("ProgressBar.node")
struct ProgressBarNodeTests {

    @Test("node() carries raw current/total/showPercentage with default color role")
    func nodeDefaults() {
        let node = ProgressBar(current: 7, total: 10).node()
        #expect(node == .progressBar(current: 7, total: 10, showPercentage: true, color: .accent))
    }

    @Test("node() passes values through raw and honors a chosen color role")
    func nodeCustom() {
        let node = ProgressBar(current: 3, total: 10, showPercentage: false).node(color: .success)
        #expect(node == .progressBar(current: 3, total: 10, showPercentage: false, color: .success))
    }
}

@Suite("ProgressBar parity (token→node→cell == legacy)")
struct ProgressBarParityTests {

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

    private func rowsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int) -> Bool {
        guard width > 0 else { return true }
        for x in 0..<width where a[x, 0] != b[x, 0] { return false }
        return true
    }

    @Test("parity across current × total × showPercentage × width, incl. zero-total & overflow")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let role = ColorRole.accent
        let style = tokenStyle(role)

        let pairs: [(Double, Double)] = [(0, 10), (3, 10), (7, 10), (10, 10), (15, 10), (0, 0), (5, 0)]
        for (current, total) in pairs {
            for showPct in [true, false] {
                for width in [1, 10, 40] {
                    var legacyFrame = makeFrame(width: width, height: 1)
                    ProgressBar(current: current, total: total, style: style, showPercentage: showPct)
                        .render(into: &legacyFrame)

                    var nodeFrame = makeFrame(width: width, height: 1)
                    renderer.render(
                        ProgressBar(current: current, total: total, showPercentage: showPct).node(color: role),
                        into: &nodeFrame)

                    #expect(rowsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: width),
                            "mismatch at current=\(current) total=\(total) showPct=\(showPct) width=\(width)")
                }
            }
        }
    }
}
