// TreeNodeTests.swift
// SwiftGUIKit
// Phase 1 — Tree: the generic/closure widget. Demonstrates the projection
// boundary — Tree<T> + renderNode closure are resolved into a concrete
// TreeDisplayNode tree of display strings at .node() time, so the scene graph
// stays monomorphic and Equatable.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Tree.node (projection boundary)")
struct TreeNodeTests {

    @Test("node() applies renderNode, resolving Tree<Int> into concrete display strings")
    func projectsGenericValues() {
        let tree = Tree<Int>(
            roots: [.init(value: 1, children: [.init(value: 2, id: "b")], id: "a")],
            state: TreeState(expandedNodes: ["a"], selectedNode: "b"),
            renderNode: { "n\($0)" })

        #expect(tree.node() == .tree(
            roots: [TreeDisplayNode(text: "n1", id: "a", children: [TreeDisplayNode(text: "n2", id: "b")])],
            expanded: ["a"], selected: "b", scrollOffset: 0, indentWidth: 2, itemColor: .label, id: ""))
    }

    @Test("node() carries scroll/indent and a chosen color role")
    func carriesStateAndColor() {
        let tree = Tree<String>(
            roots: [.init(value: "x", id: "x")],
            state: TreeState(scrollOffset: 4),
            renderNode: { $0 }, indentWidth: 4)
        #expect(tree.node(itemColor: .secondaryLabel) == .tree(
            roots: [TreeDisplayNode(text: "x", id: "x")],
            expanded: [], selected: nil, scrollOffset: 4, indentWidth: 4, itemColor: .secondaryLabel, id: ""))
    }
}

@Suite("Tree parity (token→node→cell == legacy)")
struct TreeParityTests {

    private let resolver = TerminalTokenResolver(theme: .dark)
    private let ctx = DesignContext.terminalTruecolor

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    private func sampleTree(expanded: Set<String>, selected: String?, scroll: Int, indent: Int,
                            highlight: CellStyle) -> Tree<String> {
        Tree<String>(
            roots: [
                .init(value: "root-one", children: [
                    .init(value: "child-1a", id: "1a"),
                    .init(value: "child-1b with a fairly long label", children: [.init(value: "grandchild", id: "gc")], id: "1b"),
                ], id: "1"),
                .init(value: "root-two", id: "2"),
            ],
            state: TreeState(expandedNodes: expanded, selectedNode: selected, scrollOffset: scroll),
            renderNode: { $0 },
            highlightStyle: highlight,
            indentWidth: indent)
    }

    @Test("parity across expansion × selection × scroll × indent × size, incl. long-label overflow")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let base = resolver.color(.label, in: ctx)
        let normal = CellStyle(fg: base.color, bg: .default, attributes: base.attributes)
        let focusAttrs = resolver.style(for: .focused, in: ctx).attributes
        let highlight = CellStyle(fg: normal.fg, bg: normal.bg, attributes: normal.attributes.union(focusAttrs))

        let expansions: [Set<String>] = [[], ["1"], ["1", "1b"], ["1", "1b", "2"]]
        for expanded in expansions {
            for selected in [String?.none, "1", "1a", "gc", "nope"] {
                for scroll in [0, 1] {
                    for indent in [2, 4] {
                        for (width, height) in [(5, 2), (20, 6), (40, 10)] {
                            let tree = sampleTree(expanded: expanded, selected: selected,
                                                  scroll: scroll, indent: indent, highlight: highlight)

                            var legacyFrame = makeFrame(width: width, height: height)
                            tree.render(into: &legacyFrame)

                            var nodeFrame = makeFrame(width: width, height: height)
                            renderer.render(tree.node(), into: &nodeFrame)

                            #expect(gridsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: width, height: height),
                                    "mismatch exp=\(expanded) sel=\(String(describing: selected)) scroll=\(scroll) indent=\(indent) \(width)x\(height)")
                        }
                    }
                }
            }
        }
    }
}
