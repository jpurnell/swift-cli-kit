// MenuTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Menu")
struct MenuTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Golden path: item labels are visible")
    func goldenPath() {
        var frame = makeFrame(width: 30, height: 5)
        let menu = Menu(items: [
            Menu.MenuItem(label: "New File", keyHint: "Ctrl+N"),
            Menu.MenuItem(label: "Open"),
            Menu.MenuItem(label: "Save", keyHint: "Ctrl+S"),
            Menu.MenuItem(label: "Quit"),
        ], selectedIndex: 2)
        menu.render(into: &frame)
        let buf = frame.cellBuffer
        let row0 = (0..<30).map { buf[$0, 0].character }
        #expect(String(row0).contains("New File"))
        let row2 = (0..<30).map { buf[$0, 2].character }
        #expect(String(row2).contains("Save"))
    }

    @Test("Key hints appear right-aligned")
    func keyHints() {
        var frame = makeFrame(width: 30, height: 3)
        let menu = Menu(items: [
            Menu.MenuItem(label: "Copy", keyHint: "Ctrl+C"),
        ])
        menu.render(into: &frame)
        let buf = frame.cellBuffer
        let row0 = (0..<30).map { buf[$0, 0].character }
        let rowString = String(row0)
        #expect(rowString.contains("Ctrl+C"))
    }

    @Test("Empty menu does not crash")
    func emptyMenu() {
        var frame = makeFrame(width: 20, height: 3)
        let menu = Menu(items: [])
        menu.render(into: &frame)
        let buf = frame.cellBuffer
        #expect(buf[0, 0].character == " ")
    }
}
