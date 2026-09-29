// IntrinsicSizingTests.swift
// SwiftGUIKit
// Phase D — intrinsic sizing. `measure()` reports a node's natural size; a `.fit`
// stack child is measured and pinned to `.fixed(measured)` before layout, so it
// composes with `.fixed` and `.flex` in one stack.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Intrinsic sizing (measure + .fit)")
struct IntrinsicSizingTests {

    private let r = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }
    private func ch(_ s: String) -> Node { Paragraph(text: s).node() }

    @Test("measure: paragraph height equals its wrapped-line count")
    func measureParagraph() {
        let text = "the quick brown fox jumps over"
        let node = Paragraph(text: text, wrap: true).node()
        let size = r.measure(node, available: Size(width: 10, height: 100))
        let expected = Paragraph(text: text, wrap: true).wrappedLines(width: 10).count
        #expect(size.height == expected)
        #expect(size.width == 10)
    }

    @Test("measure: list height equals item count")
    func measureList() {
        let node = List(items: [.init(text: "a"), .init(text: "b"), .init(text: "c")]).node()
        #expect(r.measure(node, available: Size(width: 20, height: 100)).height == 3)
    }

    @Test("measure: table height is header + rows")
    func measureTable() {
        let t = Table<[String]>(columns: [.init(header: "H", width: .fixed(4)) { $0[0] }],
                                rows: [["a"], ["b"]])
        #expect(r.measure(t.node(), available: Size(width: 10, height: 100)).height == 3)  // 1 header + 2 rows
    }

    @Test("measure: vstack sums children plus gaps")
    func measureVStack() {
        // two 1-row gauges, .xs (0) spacing → height 2.
        let node = Node.vstack(spacing: .xs, [Gauge(ratio: 1).node(), Gauge(ratio: 0).node()])
        #expect(r.measure(node, available: Size(width: 4, height: 100)).height == 2)
    }

    @Test("a .fit child sizes to its content, between fixed and flex")
    func fitComposesInStack() {
        let node = Node.vstack(spacing: .xs, [
            StackChild(ch("A"), size: .fixed(1)),
            StackChild(Paragraph(text: "L1\nL2").node(), size: .fit),   // measures to 2 rows
            StackChild(ch("B"), size: .flex(1)),
        ])
        var frame = makeFrame(width: 6, height: 6)
        r.render(node, into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == "A")   // fixed row 0
        #expect(buf[0, 1].character == "L")   // fit paragraph line 1 (row 1)
        #expect(buf[0, 2].character == "L")   // fit paragraph line 2 (row 2)
        #expect(buf[0, 3].character == "B")   // flex fills from row 3
    }

    @Test("measure: block adds its border sides around the child")
    func measureBlock() {
        let inner = List(items: [.init(text: "a"), .init(text: "b")]).node()   // height 2
        let block = Block(borders: .all).node(child: inner)
        // .all borders add 1 on each side → height 2 + 2 = 4.
        #expect(r.measure(block, available: Size(width: 10, height: 100)).height == 4)
    }
}
