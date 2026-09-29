// FormControlNodeTests.swift
// SwiftGUIKit
// Phase 1 — Dropdown, TextField, TextArea, CalendarView via reconstruct-and-call.
// Focus is deferred (interaction phase): the node renders the resting state, so
// legacy render(focused: false) is the parity oracle.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

private func makeFrame(width: Int, height: Int) -> Frame {
    Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
}
private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
    for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
    return true
}
private let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)

@Suite("Dropdown.node")
struct DropdownNodeTests {
    @Test("node() carries label/options/selection/expanded")
    func nodeShape() {
        var d = Dropdown(label: "Color", options: ["Red", "Green"], selectedIndex: 1)
        d.isExpanded = true
        #expect(d.node() == .dropdown(label: "Color", options: ["Red", "Green"], selectedIndex: 1,
                                      isExpanded: true, id: "", color: .label))
    }

    @Test("parity across expanded/collapsed × selection × size")
    func parity() {
        for expanded in [false, true] {
            for selected in [0, 1] {
                for (w, h) in [(20, 1), (24, 4)] {
                    var d = Dropdown(label: "Color", options: ["Red", "Green", "Blue"], selectedIndex: selected)
                    d.isExpanded = expanded
                    var legacy = makeFrame(width: w, height: h); d.render(into: &legacy, focused: false)
                    var node = makeFrame(width: w, height: h); renderer.render(d.node(), into: &node)
                    #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: w, height: h))
                }
            }
        }
    }
}

@Suite("TextField.node")
struct TextFieldNodeTests {
    @Test("node() carries label/placeholder/text")
    func nodeShape() {
        #expect(TextField(label: "Name", placeholder: "Enter…", text: "Bob").node()
                == .textField(label: "Name", placeholder: "Enter…", text: "Bob", id: "", color: .label))
    }

    @Test("parity across text/placeholder × size")
    func parity() {
        for (label, placeholder, text) in [("Name", "Enter…", ""), ("", "", "Alice"), ("Tag", "", "hi")] {
            for (w, h) in [(24, 3), (16, 3)] {
                let f = TextField(label: label, placeholder: placeholder, text: text)
                var legacy = makeFrame(width: w, height: h); f.render(into: &legacy, focused: false)
                var node = makeFrame(width: w, height: h); renderer.render(f.node(), into: &node)
                #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: w, height: h))
            }
        }
    }
}

@Suite("TextArea.node")
struct TextAreaNodeTests {
    @Test("node() carries text and scroll offset")
    func nodeShape() {
        var a = TextArea(text: "one\ntwo\nthree")
        a.scrollOffset = 1
        #expect(a.node() == .textArea(text: "one\ntwo\nthree", scrollOffset: 1, id: "", color: .label))
    }

    @Test("parity across content × scroll × size")
    func parity() {
        for content in ["", "single", "a\nb\nc\nd"] {
            for scroll in [0, 1] {
                for (w, h) in [(10, 2), (20, 4)] {
                    var a = TextArea(text: content); a.scrollOffset = scroll
                    var legacy = makeFrame(width: w, height: h); a.render(into: &legacy, focused: false)
                    var node = makeFrame(width: w, height: h); renderer.render(a.node(), into: &node)
                    #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: w, height: h))
                }
            }
        }
    }
}

@Suite("CalendarView.node")
struct CalendarNodeTests {
    @Test("node() carries year/month/selection/highlights/weekNumbers")
    func nodeShape() {
        #expect(CalendarView(year: 2026, month: 4, selectedDay: 15, highlightedDays: [1, 20], showWeekNumbers: true).node()
                == .calendar(year: 2026, month: 4, selectedDay: 15, highlightedDays: [1, 20],
                             showWeekNumbers: true, color: .label))
    }

    @Test("parity: selected=reverse (focused), highlighted=bold (heading) match legacy defaults")
    func parity() {
        for month in [1, 4, 12] {
            for selected in [Int?.none, 15] {
                for weeks in [false, true] {
                    let cal = CalendarView(year: 2026, month: month, selectedDay: selected,
                                           highlightedDays: [3, 22], showWeekNumbers: weeks)
                    var legacy = makeFrame(width: 30, height: 10); cal.render(into: &legacy)
                    var node = makeFrame(width: 30, height: 10); renderer.render(cal.node(), into: &node)
                    #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: 30, height: 10),
                            "mismatch month=\(month) sel=\(String(describing: selected)) weeks=\(weeks)")
                }
            }
        }
    }
}
