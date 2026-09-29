// AccessibleWidgetTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
@testable import SwiftCLIKit

@Suite("AccessibleWidget Conformances")
struct AccessibleWidgetTests {

    @Test("Table label reports row count and selection")
    func tableLabel() {
        let table = Table(
            columns: [
                Table.Column(header: "Name", width: .fixed(10)) { (row: String) in row },
            ],
            rows: ["Alice", "Bob", "Carol"],
            state: TableState(selectedRow: 1)
        )
        let label = table.accessibilityLabel
        #expect(label.role == .table)
        #expect(label.label.contains("3 rows"))
        #expect(label.label.contains("row 2"))
        #expect(label.childCount == 3)
    }

    @Test("List label reports item count and selected item text")
    func listLabel() {
        let list = List(
            items: [
                List.Item(text: "Alpha"),
                List.Item(text: "Beta"),
                List.Item(text: "Gamma"),
                List.Item(text: "Delta"),
                List.Item(text: "Epsilon"),
            ],
            state: ListState(selectedIndex: 2)
        )
        let label = list.accessibilityLabel
        #expect(label.role == .list)
        #expect(label.label.contains("5 items"))
        #expect(label.label.contains("Gamma"))
        #expect(label.childCount == 5)
    }

    @Test("Menu label reports item count and selected label")
    func menuLabel() {
        let menu = Menu(
            items: [
                Menu.MenuItem(label: "New"),
                Menu.MenuItem(label: "Open"),
                Menu.MenuItem(label: "Save"),
                Menu.MenuItem(label: "Quit"),
            ],
            selectedIndex: 0
        )
        let label = menu.accessibilityLabel
        #expect(label.role == .menu)
        #expect(label.label.contains("4 items"))
        #expect(label.label.contains("New"))
        #expect(label.childCount == 4)
    }

    @Test("Gauge label reports percentage")
    func gaugeLabel() {
        let gauge = Gauge(ratio: 0.75, label: "CPU")
        let label = gauge.accessibilityLabel
        #expect(label.role == .gauge)
        #expect(label.label == "CPU")
        #expect(label.value == "75%")
    }

    @Test("Tabs label reports active title and position")
    func tabsLabel() {
        let tabs = Tabs(titles: ["Home", "Settings", "About"], activeIndex: 1)
        let label = tabs.accessibilityLabel
        #expect(label.role == .tab)
        #expect(label.label.contains("Settings"))
        #expect(label.label.contains("2 of 3"))
        #expect(label.childCount == 3)
    }

    @Test("Tree label reports root count and expanded count")
    func treeLabel() {
        let tree = Tree(
            roots: [
                Tree.TreeNode(value: "Root A", children: [], id: "a"),
                Tree.TreeNode(value: "Root B", children: [], id: "b"),
            ],
            state: TreeState(expandedNodes: ["a"]),
            renderNode: { $0 }
        )
        let label = tree.accessibilityLabel
        #expect(label.role == .tree)
        #expect(label.label.contains("2 roots"))
        #expect(label.label.contains("1 expanded"))
        #expect(label.childCount == 2)
    }

    @Test("CalendarView label reports month, year, and selected day")
    func calendarLabel() {
        let cal = CalendarView(year: 2026, month: 4, selectedDay: 15)
        let label = cal.accessibilityLabel
        #expect(label.role == .calendar)
        #expect(label.label.contains("April 2026"))
        #expect(label.label.contains("day 15"))
    }
}
