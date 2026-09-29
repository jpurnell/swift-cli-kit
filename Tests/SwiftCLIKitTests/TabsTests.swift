// TabsTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Tabs")
struct TabsTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Golden path: active tab text is visible")
    func goldenPath() {
        var frame = makeFrame(width: 40, height: 1)
        let tabs = Tabs(titles: ["Home", "Settings", "About"], activeIndex: 1)
        tabs.render(into: &frame)
        let buf = frame.cellBuffer
        let row = (0..<40).map { buf[$0, 0].character }
        let rowString = String(row)
        #expect(rowString.contains("Settings"))
    }

    @Test("Single tab renders without separator")
    func singleTab() {
        var frame = makeFrame(width: 20, height: 1)
        let tabs = Tabs(titles: ["Only"])
        tabs.render(into: &frame)
        let buf = frame.cellBuffer
        let row = (0..<20).map { buf[$0, 0].character }
        let rowString = String(row)
        #expect(rowString.contains("Only"))
        // No separator should be present
        #expect(!rowString.contains("|"))
    }

    @Test("Separator characters appear between tabs")
    func separatorPresent() {
        var frame = makeFrame(width: 40, height: 1)
        let tabs = Tabs(titles: ["A", "B", "C"])
        tabs.render(into: &frame)
        let buf = frame.cellBuffer
        let row = (0..<40).map { buf[$0, 0].character }
        let rowString = String(row)
        #expect(rowString.contains("|"))
    }
}
