// ListTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("List")
struct ListTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Golden path: 5 items rendered in a 20x5 frame")
    func goldenPath() {
        var frame = makeFrame(width: 20, height: 5)
        let items = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"].map { List.Item(text: $0) }
        let list = List(items: items)
        list.render(into: &frame)
        let buf = frame.cellBuffer
        // Each row should contain the corresponding item text
        let row0 = (0..<20).map { buf[$0, 0].character }
        #expect(String(row0).contains("Alpha"))
        let row2 = (0..<20).map { buf[$0, 2].character }
        #expect(String(row2).contains("Gamma"))
    }

    @Test("Selected index item has highlight style")
    func selectedHighlight() {
        var frame = makeFrame(width: 20, height: 5)
        let items = ["A", "B", "C", "D", "E"].map { List.Item(text: $0) }
        let highlight = CellStyle(fg: .ansi8(.red), attributes: [.reverse])
        let list = List(items: items, state: ListState(selectedIndex: 2), highlightStyle: highlight)
        list.render(into: &frame)
        let buf = frame.cellBuffer
        // Row 2 should have the highlight style
        let cell = buf[0, 2]
        #expect(cell.fg == .ansi8(.red) || cell.attributes.contains(.reverse))
    }

    @Test("Empty list does not crash")
    func emptyList() {
        var frame = makeFrame(width: 20, height: 5)
        let list = List(items: [])
        list.render(into: &frame)
        let buf = frame.cellBuffer
        // All cells should remain empty (spaces)
        #expect(buf[0, 0].character == " ")
    }

    @Test("Scroll offset shows correct visible items")
    func scrollOffset() {
        var frame = makeFrame(width: 20, height: 5)
        let items = (0..<20).map { List.Item(text: "Item \($0)") }
        let list = List(items: items, state: ListState(scrollOffset: 5))
        list.render(into: &frame)
        let buf = frame.cellBuffer
        // First visible row should show "Item 5"
        let row0 = (0..<20).map { buf[$0, 0].character }
        #expect(String(row0).contains("Item 5"))
    }
}
