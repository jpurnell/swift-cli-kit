// TableNodeTests.swift
// SwiftGUIKit
// Phase 1 — Table: the capstone. Generic over Row with per-column render
// closures (projection boundary, like Tree) AND it renders ▲/▼ sort indicators
// that match glyph(.sortAscending/.sortDescending) — completing the sort symbols
// with real byte-parity.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Table.node (projection boundary)")
struct TableNodeTests {

    private func nameAge(_ rows: [[String]], sort: (column: Int, ascending: Bool)? = nil,
                         state: TableState = TableState()) -> Table<[String]> {
        Table<[String]>(
            columns: [
                .init(header: "Name", width: .fixed(10)) { $0[0] },
                .init(header: "Age", width: .fixed(5)) { $0[1] },
            ],
            rows: rows, state: state, sortIndicator: sort)
    }

    @Test("node() projects rows through each column's render closure into concrete cells")
    func projectsCells() {
        let table = nameAge([["Alice", "30"], ["Bob", "25"]],
                            sort: (column: 0, ascending: true),
                            state: TableState(selectedRow: 1, scrollOffset: 0))
        #expect(table.node() == .table(
            headers: ["Name", "Age"], widths: [.fixed(10), .fixed(5)],
            cells: [["Alice", "30"], ["Bob", "25"]],
            selectedRow: 1, scrollOffset: 0, sort: TableSort(column: 0, ascending: true),
            headerColor: .label, rowColor: .label, id: ""))
    }

    @Test("node() carries no sort when none is set")
    func noSort() {
        let node = nameAge([["X", "1"]]).node()
        #expect(node == .table(headers: ["Name", "Age"], widths: [.fixed(10), .fixed(5)],
                               cells: [["X", "1"]], selectedRow: nil, scrollOffset: 0,
                               sort: nil, headerColor: .label, rowColor: .label, id: ""))
    }
}

@Suite("Table parity (token→node→cell == legacy)")
struct TableParityTests {

    private let resolver = TerminalTokenResolver(theme: .dark)
    private let ctx = DesignContext.terminalTruecolor

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    private func table(rows: [[String]], sort: (column: Int, ascending: Bool)?,
                       state: TableState, widths: [Layout.Constraint]) -> Table<[String]> {
        Table<[String]>(
            columns: [
                .init(header: "Name", width: widths[0]) { $0[0] },
                .init(header: "Age", width: widths[1]) { $0[1] },
            ],
            rows: rows, state: state, sortIndicator: sort)
    }

    @Test("parity across rows × selection × scroll × sort × width constraints × size")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let rowsets: [[[String]]] = [
            [],
            [["Alice", "30"]],
            [["Alice", "30"], ["Bob", "25"], ["Carol", "28"]],
        ]
        let widthSets: [[Layout.Constraint]] = [[.fixed(10), .fixed(5)], [.ratio(1, 2), .ratio(1, 2)]]
        let sorts: [(column: Int, ascending: Bool)?] = [nil, (0, true), (1, false)]

        for rows in rowsets {
            for widths in widthSets {
                for sort in sorts {
                    for selected in [Int?.none, 0, 1] {
                        for scroll in [0, 1] {
                            for (width, height) in [(16, 3), (30, 5)] {
                                let t = table(rows: rows, sort: sort,
                                              state: TableState(selectedRow: selected, scrollOffset: scroll),
                                              widths: widths)
                                var legacy = makeFrame(width: width, height: height)
                                t.render(into: &legacy)
                                var node = makeFrame(width: width, height: height)
                                renderer.render(t.node(), into: &node)
                                #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: width, height: height),
                                        "mismatch rows=\(rows.count) sort=\(String(describing: sort)) sel=\(String(describing: selected)) scroll=\(scroll) \(width)x\(height)")
                            }
                        }
                    }
                }
            }
        }
    }
}
