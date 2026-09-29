// Table+Node.swift
// SwiftGUIKit
//
// Projects the generic SwiftCLIKit `Table<Row>` into the semantic scene graph.
// The projection boundary (see §7½): the generic Row type and each column's
// render closure are resolved into concrete cell strings here. The legacy render
// path is untouched.

import SwiftCLIKit

public extension Table {
    /// Projects this table into a semantic ``Node``.
    ///
    /// Each row is run through every column's render closure, producing a concrete
    /// `rows × columns` grid of strings; headers, width constraints, sort, and
    /// selection/scroll state pass through.
    /// - Parameters:
    ///   - headerColor: The header text color role (default: ``ColorRole/label``).
    ///   - rowColor: The data-row text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/table(headers:widths:cells:selectedRow:scrollOffset:sort:headerColor:rowColor:)`` node.
    func node(id: String = "", headerColor: ColorRole = .label, rowColor: ColorRole = .label) -> Node {
        .table(
            headers: columns.map(\.header),
            widths: columns.map(\.width),
            cells: rows.map { row in columns.map { $0.render(row) } },
            selectedRow: state.selectedRow,
            scrollOffset: state.scrollOffset,
            sort: sortIndicator.map { TableSort(column: $0.column, ascending: $0.ascending) },
            headerColor: headerColor,
            rowColor: rowColor,
            id: id
        )
    }
}
