// ScrollbarNodeTests.swift
// SwiftGUIKit
// Phase 1 — Scrollbar: a reconstruct-and-call port. Thumb = accent, track =
// separator (semantic defaults); CellRenderer rebuilds the widget with those
// token-resolved styles and calls Scrollbar.render.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Scrollbar.node")
struct ScrollbarNodeTests {

    @Test("node() carries geometry with default track/thumb color roles")
    func nodeDefaults() {
        #expect(Scrollbar(orientation: .vertical, contentLength: 100, viewportSize: 20, offset: 25).node()
                == .scrollbar(orientation: .vertical, contentLength: 100, viewportSize: 20, offset: 25,
                              trackColor: .separator, thumbColor: .accent))
    }
}

@Suite("Scrollbar parity (token→node→cell == legacy)")
struct ScrollbarParityTests {

    private let resolver = TerminalTokenResolver(theme: .dark)
    private let ctx = DesignContext.terminalTruecolor

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func tokenStyle(_ role: ColorRole) -> CellStyle {
        let r = resolver.color(role, in: ctx)
        return CellStyle(fg: r.color, bg: .default, attributes: r.attributes)
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    @Test("parity across orientation × content/viewport/offset × size")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let track = tokenStyle(.separator)
        let thumb = tokenStyle(.accent)

        for orientation in [Scrollbar.Orientation.vertical, .horizontal] {
            for (content, viewport) in [(100, 20), (10, 20), (50, 25)] {
                for offset in [0, 25, 80] {
                    for (width, height) in [(1, 10), (20, 1)] {
                        let bar = Scrollbar(orientation: orientation, contentLength: content,
                                            viewportSize: viewport, offset: offset,
                                            trackStyle: track, thumbStyle: thumb)
                        var legacy = makeFrame(width: width, height: height)
                        bar.render(into: &legacy)
                        var node = makeFrame(width: width, height: height)
                        renderer.render(bar.node(), into: &node)
                        #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: width, height: height),
                                "mismatch \(orientation) c=\(content) v=\(viewport) o=\(offset) \(width)x\(height)")
                    }
                }
            }
        }
    }
}
