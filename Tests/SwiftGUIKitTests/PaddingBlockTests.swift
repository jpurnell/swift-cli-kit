// PaddingBlockTests.swift
// SwiftGUIKit
// Container nodes C2 (padding) + C3 (Block port). Block uses reconstruct-and-call:
// reuse Block.render for the border, recurse into the inner frame it returns.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

private let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
private func makeFrame(width: Int, height: Int) -> Frame {
    Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
}
private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
    for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
    return true
}
private func ch(_ s: String) -> Node { Paragraph(text: s).node() }

@Suite("Padding container")
struct PaddingTests {
    private func render(_ node: Node, width: Int, height: Int) -> CellBuffer {
        var frame = makeFrame(width: width, height: height); renderer.render(node, into: &frame); return frame.cellBuffer
    }

    @Test("padding insets the child by the resolved spacing per axis")
    func insets() {
        // .s → horizontal 1 cell, vertical ceil(1/2)=1 cell.
        let buf = render(.padding(.s, child: ch("X")), width: 5, height: 5)
        #expect(buf[1, 1].character == "X")   // child origin shifted by (h, v) inset
        #expect(buf[0, 0].character == " ")   // padding region empty
    }

    @Test("padding nests inside a stack")
    func nestedInStack() {
        let node = Node.vstack([
            StackChild(.padding(.s, child: ch("A")), size: .fixed(3)),
            StackChild(ch("B"), size: .fixed(1)),
        ])
        let buf = render(node, width: 5, height: 4)
        #expect(buf[1, 1].character == "A")   // padded inside the 3-row top cell
        #expect(buf[0, 3].character == "B")   // bottom cell, unpadded
    }
}

@Suite("Block container (token→node→cell == legacy)")
struct BlockContainerTests {
    @Test("block border + inner content byte-match legacy render + child render")
    func parity() {
        for borders in [BorderSet.all, [.top, .bottom], BorderSet.none] {
            for title in [String?.none, "Status"] {
                for align in [Paragraph.Alignment.left, .center, .right] {
                    for (w, h) in [(10, 4), (16, 5)] {
                        let block = Block(title: title, borders: borders, titleAlignment: align)
                        let child = Paragraph(text: "Hello")   // node() renders identically to legacy default

                        var legacy = makeFrame(width: w, height: h)
                        var inner = block.render(into: &legacy)
                        child.render(into: &inner)

                        var node = makeFrame(width: w, height: h)
                        renderer.render(block.node(child: child.node()), into: &node)

                        #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: w, height: h),
                                "mismatch borders=\(borders) title=\(String(describing: title)) align=\(align) \(w)x\(h)")
                    }
                }
            }
        }
    }

    @Test("a block nests inside a stack (recursion through the border)")
    func blockInStack() {
        let block = Block(title: nil, borders: .all)
        let node = Node.vstack([ StackChild(block.node(child: ch("Z")), size: .flex(1)) ])
        var frame = makeFrame(width: 5, height: 3)
        renderer.render(node, into: &frame)
        // The .all border puts the child inside at inner origin (1,1).
        #expect(frame.cellBuffer[1, 1].character == "Z")
    }
}
