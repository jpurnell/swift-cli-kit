// TreeTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Tree")
struct TreeTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Expanded tree shows children with indent")
    func expanded() {
        let childA = Tree<String>.TreeNode(value: "Child A", children: [], id: "a")
        let childB = Tree<String>.TreeNode(value: "Child B", children: [], id: "b")
        let root = Tree<String>.TreeNode(value: "Root", children: [childA, childB], id: "root")
        var frame = makeFrame(width: 30, height: 5)
        let tree = Tree(
            roots: [root],
            state: TreeState(expandedNodes: ["root"]),
            renderNode: { $0 }
        )
        tree.render(into: &frame)
        let buf = frame.cellBuffer
        // Row 0 should contain "Root"
        let row0 = (0..<30).map { buf[$0, 0].character }
        #expect(String(row0).contains("Root"))
        // Row 1 should contain "Child A" (indented)
        let row1 = (0..<30).map { buf[$0, 1].character }
        #expect(String(row1).contains("Child A"))
    }

    @Test("Collapsed parent hides children")
    func collapsed() {
        let child = Tree<String>.TreeNode(value: "Hidden", children: [], id: "c")
        let root = Tree<String>.TreeNode(value: "Parent", children: [child], id: "root")
        var frame = makeFrame(width: 30, height: 5)
        let tree = Tree(
            roots: [root],
            state: TreeState(expandedNodes: []),
            renderNode: { $0 }
        )
        tree.render(into: &frame)
        let buf = frame.cellBuffer
        // Row 0 should contain "Parent"
        let row0 = (0..<30).map { buf[$0, 0].character }
        #expect(String(row0).contains("Parent"))
        // Row 1 should NOT contain "Hidden"
        let row1 = (0..<30).map { buf[$0, 1].character }
        #expect(!String(row1).contains("Hidden"))
    }

    @Test("Selected node has highlight style")
    func selectedNode() {
        let root = Tree<String>.TreeNode(value: "Only", children: [], id: "only")
        var frame = makeFrame(width: 20, height: 3)
        let highlight = CellStyle(fg: .ansi8(.green), attributes: [.reverse])
        let tree = Tree(
            roots: [root],
            state: TreeState(selectedNode: "only"),
            renderNode: { $0 },
            highlightStyle: highlight
        )
        tree.render(into: &frame)
        let buf = frame.cellBuffer
        let cell = buf[0, 0]
        #expect(cell.fg == .ansi8(.green) || cell.attributes.contains(.reverse))
    }

    @Test("Deep nesting (100 levels) does not crash or hang")
    func deepNesting() {
        // Build a 100-level deep chain: each node has one child
        var expandedIDs = Set<String>()
        var current = Tree<String>.TreeNode(value: "Leaf", children: [], id: "node_99")
        expandedIDs.insert("node_99")
        for i in stride(from: 98, through: 0, by: -1) {
            let id = "node_\(i)"
            current = Tree<String>.TreeNode(value: "Level \(i)", children: [current], id: id)
            expandedIDs.insert(id)
        }

        var frame = makeFrame(width: 80, height: 10)
        let tree = Tree(
            roots: [current],
            state: TreeState(expandedNodes: expandedIDs),
            renderNode: { $0 }
        )
        // Should not crash or hang — only first 10 visible nodes appear
        tree.render(into: &frame)
        let buf = frame.cellBuffer
        // Row 0 should contain "Level 0" (the root)
        let row0 = (0..<80).map { buf[$0, 0].character }
        #expect(String(row0).contains("Level 0"))
        // Row 9 should have some content from the tree (level 9)
        let row9 = (0..<80).map { buf[$0, 9].character }
        let row9Str = String(row9).trimmingCharacters(in: .whitespaces)
        #expect(!row9Str.isEmpty, "Row 9 should contain a visible node")
    }

    @Test("Empty tree does not crash")
    func emptyTree() {
        var frame = makeFrame(width: 20, height: 3)
        let tree = Tree<String>(
            roots: [],
            state: TreeState(),
            renderNode: { $0 }
        )
        tree.render(into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == " ")
    }
}
