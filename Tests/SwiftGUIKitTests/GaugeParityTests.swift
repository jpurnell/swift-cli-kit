// GaugeParityTests.swift
// SwiftGUIKit
// Phase 0 — §1d: the proving loop. The token→node→cell path must reproduce the
// legacy Gauge renderer configured with the token-resolved styles (Approach A),
// byte-for-byte, across a ratio × width × label matrix.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Gauge parity (token→node→cell == legacy)")
struct GaugeParityTests {

    private let resolver = TerminalTokenResolver(theme: .dark)
    private let ctx = DesignContext.terminalTruecolor

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    /// The `CellStyle` a `ColorRole` resolves to on this context.
    private func tokenStyle(_ role: ColorRole) -> CellStyle {
        let r = resolver.color(role, in: ctx)
        return CellStyle(fg: r.color, bg: .default, attributes: r.attributes)
    }

    /// Cell-by-cell comparison of two buffers over a single row.
    private func rowsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int) -> Bool {
        guard width > 0 else { return true }
        for x in 0..<width where a[x, 0] != b[x, 0] { return false }
        return true
    }

    @Test("parity across the ratio × width × label matrix")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let filled = tokenStyle(.accent)
        let track = tokenStyle(.separator)

        for ratio in [0.0, 0.25, 0.5, 0.75, 1.0] {
            for width in [1, 10, 40] {
                for label in [String?.none, "75%"] {
                    // Legacy path, configured with the token-resolved styles (Approach A).
                    var legacyFrame = makeFrame(width: width, height: 1)
                    Gauge(ratio: ratio, label: label, filledStyle: filled, unfilledStyle: track)
                        .render(into: &legacyFrame)

                    // Token → node → cell path.
                    var nodeFrame = makeFrame(width: width, height: 1)
                    renderer.render(Gauge(ratio: ratio, label: label).node(), into: &nodeFrame)

                    #expect(rowsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: width),
                            "mismatch at ratio=\(ratio) width=\(width) label=\(String(describing: label))")
                }
            }
        }
    }

    @Test("out-of-range ratios clamp identically on both paths")
    func clampParity() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let filled = tokenStyle(.accent)
        let track = tokenStyle(.separator)

        for ratio in [-0.5, 1.5] {
            var legacyFrame = makeFrame(width: 20, height: 1)
            Gauge(ratio: ratio, filledStyle: filled, unfilledStyle: track).render(into: &legacyFrame)
            var nodeFrame = makeFrame(width: 20, height: 1)
            renderer.render(Gauge(ratio: ratio).node(), into: &nodeFrame)
            #expect(rowsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: 20))
        }
    }

    @Test("zero width produces empty output on both paths (guard parity)")
    func zeroWidthParity() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        var legacyFrame = makeFrame(width: 0, height: 1)
        Gauge(ratio: 0.5).render(into: &legacyFrame)
        var nodeFrame = makeFrame(width: 0, height: 1)
        renderer.render(Gauge(ratio: 0.5).node(), into: &nodeFrame)
        #expect(rowsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: 0))
    }
}
