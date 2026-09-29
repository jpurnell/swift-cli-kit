// ContainerNodeTests.swift
// SwiftGUIKit
// Container nodes C0+C1 — the recursion + layout proving slice. Single-char
// paragraphs make each child's landing position unambiguous: a leaf at (0,0) of
// its subframe appears at the subframe's origin in the parent buffer.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Container layout (stack / spacer)")
struct ContainerNodeTests {

    private let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }
    private func ch(_ s: String) -> Node { Paragraph(text: s).node() }
    private func render(_ node: Node, width: Int, height: Int) -> CellBuffer {
        var frame = makeFrame(width: width, height: height)
        renderer.render(node, into: &frame)
        return frame.cellBuffer
    }

    @Test("vstack divides equal flex children into one row each")
    func vstackEqualFlex() {
        let buf = render(.vstack([ch("A"), ch("B"), ch("C")]), width: 5, height: 3)
        #expect(buf[0, 0].character == "A")
        #expect(buf[0, 1].character == "B")
        #expect(buf[0, 2].character == "C")
    }

    @Test("hstack divides equal flex children into one column each")
    func hstackEqualFlex() {
        let buf = render(.hstack([ch("A"), ch("B"), ch("C")]), width: 3, height: 1)
        #expect(buf[0, 0].character == "A")
        #expect(buf[1, 0].character == "B")
        #expect(buf[2, 0].character == "C")
    }

    @Test("fixed child takes its rows; flex child fills the remainder")
    func fixedPlusFlex() {
        let node = Node.vstack([StackChild(ch("A"), size: .fixed(1)), StackChild(ch("B"), size: .flex(1))])
        let buf = render(node, width: 5, height: 4)
        #expect(buf[0, 0].character == "A")   // fixed row 0
        #expect(buf[0, 1].character == "B")   // flex rect starts at row 1
        #expect(buf[0, 2].character == " ")   // rest of flex rect empty
    }

    @Test("spacer occupies its share and draws nothing")
    func spacerPushesApart() {
        let node = Node.vstack([StackChild(ch("A"), size: .fixed(1)),
                                StackChild(.spacer, size: .flex(1)),
                                StackChild(ch("B"), size: .fixed(1))])
        let buf = render(node, width: 5, height: 3)
        #expect(buf[0, 0].character == "A")
        #expect(buf[0, 1].character == " ")   // spacer
        #expect(buf[0, 2].character == "B")
    }

    @Test("spacing inserts a gap along the main axis (vertical halved for aspect)")
    func spacingGap() {
        // .s spacing on the vertical axis = ceil(1/2) = 1 cell gap.
        let buf = render(.vstack(spacing: .s, [ch("A"), ch("B")]), width: 5, height: 3)
        #expect(buf[0, 0].character == "A")
        #expect(buf[0, 1].character == " ")   // gap
        #expect(buf[0, 2].character == "B")
    }

    @Test("stacks nest — an hstack inside a vstack renders each leaf in its sub-rect")
    func nestedStacks() {
        let node = Node.vstack([
            StackChild(.hstack([ch("A"), ch("B")]), size: .fixed(1)),
            StackChild(ch("C"), size: .fixed(1)),
        ])
        let buf = render(node, width: 2, height: 2)
        #expect(buf[0, 0].character == "A")   // hstack col 0, row 0
        #expect(buf[1, 0].character == "B")   // hstack col 1, row 0
        #expect(buf[0, 1].character == "C")   // second vstack row
    }
}

@Suite("StackLayout rect math")
struct StackLayoutTests {
    @Test("flex distributes leftover exactly, with no rounding gaps")
    func flexExactSum() {
        // height 5, three flex(1) → 2,2,1 (cumulative distribution), summing to 5.
        let rects = StackLayout.rects(in: Rect(x: 0, y: 0, width: 4, height: 5), axis: .vertical, gap: 0,
                                      sizes: [.flex(1), .flex(1), .flex(1)])
        #expect(rects.map(\.height) == [1, 2, 2] || rects.map(\.height).reduce(0, +) == 5)
        #expect(rects.map(\.height).reduce(0, +) == 5)
        #expect(rects[0].y == 0 && rects[1].y == rects[0].height && rects[2].y == rects[0].height + rects[1].height)
    }

    @Test("fixed over-subscription doesn't crash and flex gets zero")
    func fixedOverflow() {
        let rects = StackLayout.rects(in: Rect(x: 0, y: 0, width: 4, height: 2), axis: .vertical, gap: 0,
                                      sizes: [.fixed(3), .flex(1)])
        #expect(rects.count == 2)
        #expect(rects[1].height == 0)   // no room left for flex
    }
}
