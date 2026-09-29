// ParagraphNodeTests.swift
// SwiftGUIKit
// Phase 1 — Paragraph: a reconstruct-and-call port. The node carries the text +
// alignment + wrap; CellRenderer rebuilds the widget with the token-resolved
// color and calls Paragraph.render — zero drift by construction.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Paragraph.node")
struct ParagraphNodeTests {

    @Test("node() carries text/alignment/wrap with default color role")
    func nodeDefaults() {
        #expect(Paragraph(text: "Hello world", alignment: .center, wrap: true).node()
                == .paragraph(text: "Hello world", alignment: .center, wrap: true, color: .label))
    }

    @Test("node() honors a chosen color role and no-wrap")
    func nodeCustom() {
        #expect(Paragraph(text: "x", alignment: .right, wrap: false).node(color: .secondaryLabel)
                == .paragraph(text: "x", alignment: .right, wrap: false, color: .secondaryLabel))
    }
}

@Suite("Paragraph parity (token→node→cell == legacy)")
struct ParagraphParityTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    @Test("parity across text × alignment × wrap × size")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
        let texts = ["", "short", "the quick brown fox jumps over the lazy dog", "line one\nline two"]
        for text in texts {
            for alignment in [Paragraph.Alignment.left, .center, .right] {
                for wrap in [true, false] {
                    for (width, height) in [(10, 4), (30, 6)] {
                        let para = Paragraph(text: text, alignment: alignment, wrap: wrap)
                        var legacy = makeFrame(width: width, height: height)
                        para.render(into: &legacy)   // default fg/bg
                        var node = makeFrame(width: width, height: height)
                        renderer.render(para.node(), into: &node)   // color .label → default fg/bg
                        #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: width, height: height),
                                "mismatch align=\(alignment) wrap=\(wrap) \(width)x\(height)")
                    }
                }
            }
        }
    }
}
