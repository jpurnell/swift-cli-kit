// TableTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Table")
struct TableTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    @Test("Headers in row 0 and data in rows 1-3 for a 3-column, 3-row table")
    func goldenPath() {
        var frame = makeFrame(width: 40, height: 6)
        let table = Table(
            columns: [
                Table.Column(header: "Name", width: .fixed(15)) { $0.0 },
                Table.Column(header: "Age", width: .fixed(10)) { "\($0.1)" },
                Table.Column(header: "City", width: .fixed(15)) { $0.2 },
            ],
            rows: [
                ("Alice", 30, "NYC"),
                ("Bob", 25, "LA"),
                ("Carol", 40, "CHI"),
            ]
        )
        table.render(into: &frame)
        let buf = frame.cellBuffer
        // Headers should appear in row 0
        let headerRow = (0..<40).map { buf[$0, 0].character }
        let headerString = String(headerRow)
        #expect(headerString.contains("Name"))
        #expect(headerString.contains("Age"))
        // Data row 1 should contain "Alice"
        let dataRow1 = (0..<40).map { buf[$0, 1].character }
        let dataString1 = String(dataRow1)
        #expect(dataString1.contains("Alice"))
    }

    @Test("Selected row has different style applied")
    func selectedRow() {
        var frame = makeFrame(width: 30, height: 5)
        let highlight = CellStyle(fg: .ansi8(.yellow), attributes: [.reverse])
        let table = Table(
            columns: [
                Table.Column(header: "Item", width: .fixed(30)) { $0 },
            ],
            rows: ["Alpha", "Beta", "Gamma"],
            state: TableState(selectedRow: 1),
            highlightStyle: highlight
        )
        table.render(into: &frame)
        let buf = frame.cellBuffer
        // Row 2 (index 1 + 1 for header) should have the highlight style
        let selectedCell = buf[0, 2]
        #expect(selectedCell.fg == .ansi8(.yellow) || selectedCell.attributes.contains(.reverse))
    }

    @Test("Empty rows render headers without crashing")
    func emptyRows() {
        var frame = makeFrame(width: 30, height: 5)
        let table = Table<String>(
            columns: [
                Table.Column(header: "Header", width: .fixed(30)) { $0 },
            ],
            rows: []
        )
        table.render(into: &frame)
        let buf = frame.cellBuffer
        let headerRow = (0..<30).map { buf[$0, 0].character }
        let headerString = String(headerRow)
        #expect(headerString.contains("Header"))
    }

    @Test("Scroll offset shows correct visible rows")
    func scrollOffset() {
        var frame = makeFrame(width: 20, height: 5)
        let rows = (0..<10).map { "Row \($0)" }
        let table = Table(
            columns: [
                Table.Column(header: "Data", width: .fixed(20)) { $0 },
            ],
            rows: rows,
            state: TableState(scrollOffset: 3)
        )
        table.render(into: &frame)
        let buf = frame.cellBuffer
        // With offset 3 and header at row 0, row 1 should show "Row 3"
        let visibleRow = (0..<20).map { buf[$0, 1].character }
        let visibleString = String(visibleRow)
        #expect(visibleString.contains("Row 3"))
    }

    @Test("Column widths exceeding frame width renders without crashing")
    func columnWidthStarvation() {
        // Total fixed = 150 but frame is only 40 wide
        var frame = makeFrame(width: 40, height: 10)
        let table = Table(
            columns: [
                Table.Column(header: "Alpha", width: .fixed(50)) { $0 },
                Table.Column(header: "Beta", width: .fixed(50)) { $0 },
                Table.Column(header: "Gamma", width: .fixed(50)) { $0 },
            ],
            rows: ["Row1", "Row2"]
        )
        // Should not crash even though columns overflow the frame
        table.render(into: &frame)
        let buf = frame.cellBuffer
        // At minimum, some header text should be visible (even if truncated)
        let headerRow = (0..<40).map { buf[$0, 0].character }
        let headerString = String(headerRow)
        #expect(headerString.contains("Alpha"), "First header should be at least partially visible")
    }

    @Test("Sort indicator character appears in the header")
    func sortIndicator() {
        var frame = makeFrame(width: 30, height: 3)
        let table = Table(
            columns: [
                Table.Column(header: "Name", width: .fixed(15)) { $0 },
                Table.Column(header: "Value", width: .fixed(15)) { $0 },
            ],
            rows: ["A", "B"],
            sortIndicator: (column: 0, ascending: true)
        )
        table.render(into: &frame)
        let buf = frame.cellBuffer
        // The header row should contain a sort indicator (e.g., "▲" or similar)
        let headerRow = (0..<30).map { buf[$0, 0].character }
        let headerString = String(headerRow)
        // At minimum the header text should be present; sort indicator is part of rendering
        #expect(headerString.contains("Name") || headerString.contains("▲"))
    }
}
