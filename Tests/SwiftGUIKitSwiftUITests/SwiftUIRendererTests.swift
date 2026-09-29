// SwiftUIRendererTests.swift
// SwiftGUIKitSwiftUI
// Phase 2 P2.1 — the leaf renderer + interaction. SwiftUI view trees are opaque,
// so we (1) unit-test the interaction bindings (get/set closures, no running
// view needed) and (2) smoke-test that the view builder constructs for each
// supported node without crashing.

#if canImport(SwiftUI)
import Testing
import Foundation
import SwiftUI
import SwiftCLIKit
import SwiftGUIKit
@testable import SwiftGUIKitSwiftUI

/// A Sendable accumulator so @Sendable onAction closures can record into it.
// Justification: `storage` is never touched outside `lock`, so the mutable state cannot be raced.
private final class ActionLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [NodeAction] = []

    var actions: [NodeAction] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ action: NodeAction) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(action)
    }
}

@Suite("SwiftUIRenderer (P2.1 leaves + interaction)")
struct SwiftUIRendererTests {

    private let renderer = SwiftUIRenderer()

    // MARK: Interaction (the point of this phase)

    @Test("checkbox toggle binding reads state and emits .toggled on change")
    func toggleBindingRoundTrip() {
        let log = ActionLog()
        let binding = SwiftUIRenderer.toggleBinding(false, id: "agree", onAction: { log.record($0) })
        #expect(binding.wrappedValue == false)     // reads current state
        binding.wrappedValue = true                // user flips the toggle
        #expect(log.actions == [.toggled(id: "agree", true)])
    }

    @Test("text binding reads text and emits .textChanged on edit")
    func textBindingRoundTrip() {
        let log = ActionLog()
        let binding = SwiftUIRenderer.textBinding("hi", id: "name", onAction: { log.record($0) })
        #expect(binding.wrappedValue == "hi")
        binding.wrappedValue = "hix"
        #expect(log.actions == [.textChanged(id: "name", "hix")])
    }

    @Test("selection binding emits .selected on change (radio/tabs/dropdown/menu)")
    func selectionBindingFires() {
        let log = ActionLog()
        let binding = SwiftUIRenderer.selectionBinding(0, id: "size", onAction: { log.record($0) })
        #expect(binding.wrappedValue == 0)
        binding.wrappedValue = 2
        #expect(log.actions == [.selected(id: "size", 2)])
    }

    @Test("optional selection binding (List) emits .selected only when a row is chosen")
    func optionalSelectionBindingFires() {
        let log = ActionLog()
        let binding = SwiftUIRenderer.optionalSelectionBinding(nil, id: "rows", onAction: { log.record($0) })
        #expect(binding.wrappedValue == nil)
        binding.wrappedValue = 3
        #expect(log.actions == [.selected(id: "rows", 3)])
        binding.wrappedValue = nil          // deselection emits nothing
        #expect(log.actions == [.selected(id: "rows", 3)])
    }

    @Test("tree selection binding emits .nodeSelected with the chosen node id")
    func treeSelectionBindingFires() {
        let log = ActionLog()
        // A tree selects by node identity (String), not row index — hence .nodeSelected.
        let node = Tree<String>(roots: [.init(value: "r", children: [.init(value: "c", id: "c")], id: "r")],
                                renderNode: { $0 }).node(id: "modules")
        guard case let .tree(_, _, selected, _, _, _, id) = node else { Issue.record("not a tree"); return }
        let binding = SwiftUIRenderer.treeSelectionBinding(selected, id: id, onAction: { log.record($0) })
        #expect(binding.wrappedValue == nil)
        binding.wrappedValue = "c"
        #expect(log.actions == [.nodeSelected(id: "modules", "c")])
        binding.wrappedValue = nil          // deselection emits nothing
        #expect(log.actions == [.nodeSelected(id: "modules", "c")])
    }

    @Test("Checkbox.node(id:) round-trips through the toggle binding end to end")
    func checkboxInteractionEndToEnd() {
        let log = ActionLog()
        // A checkbox node with an interaction id, as an app would build it.
        let node = Checkbox(label: "Agree", isChecked: false).node(id: "agree")
        guard case let .checkbox(isChecked, _, id, _) = node else { Issue.record("not a checkbox"); return }
        let binding = SwiftUIRenderer.toggleBinding(isChecked, id: id, onAction: { log.record($0) })
        binding.wrappedValue = true
        #expect(log.actions == [.toggled(id: "agree", true)])
    }

    @Test("form field editing routes through textBinding to .textChanged with the field id")
    func formFieldEditingFires() {
        let log = ActionLog()
        // A form field's text binding uses the field's own id, so a multi-field
        // form dispatches per-field edits (as the SwiftUI formView wires it).
        let node = Form(fields: [.init(id: "email", label: "Email", value: "a@b")]).node()
        guard case let .form(fields, _, _, _) = node, let field = fields.first else {
            Issue.record("not a form"); return
        }
        let binding = SwiftUIRenderer.textBinding(field.value, id: field.id, onAction: { log.record($0) })
        #expect(binding.wrappedValue == "a@b")
        binding.wrappedValue = "a@b.com"
        #expect(log.actions == [.textChanged(id: "email", "a@b.com")])
    }

    @Test("calendar month layout matches the terminal's Sunday-first grid, incl. leap years")
    func calendarMonthLayout() {
        // July 1 2026 is a Wednesday → 3 blank leading cells; July has 31 days.
        let july = SwiftUIRenderer.monthLayout(year: 2026, month: 7)
        #expect(july.startOffset == 3)
        #expect(july.daysInMonth == 31)
        // Non-leap vs leap February.
        #expect(SwiftUIRenderer.monthLayout(year: 2026, month: 2).daysInMonth == 28)
        #expect(SwiftUIRenderer.monthLayout(year: 2024, month: 2).daysInMonth == 29)
        #expect(SwiftUIRenderer.monthTitle(year: 2026, month: 7) == "July 2026")
    }

    // MARK: Smoke — the view builder constructs for each supported node

    private func ch(_ s: String) -> Node { Paragraph(text: s).node() }

    @Test("view(for:) constructs for every node kind, including nested containers")
    func fullCatalogSmoke() {
        let samples: [Node] = [
            Paragraph(text: "p").node(),
            Gauge(ratio: 0.5, label: "50%").node(),
            ProgressBar(current: 3, total: 10).node(),
            Sparkline(data: [1, 2, 3]).node(),
            BarChart(bars: [.init(label: "a", value: 1), .init(label: "b", value: 2)]).node(),
            List(items: [.init(text: "x"), .init(text: "y")]).node(),
            Table<[String]>(columns: [.init(header: "H", width: .fixed(3)) { $0[0] }], rows: [["a"], ["b"]]).node(),
            Tree<String>(roots: [.init(value: "r", children: [.init(value: "c", id: "c")], id: "r")],
                         renderNode: { $0 }).node(),
            Menu(items: [.init(label: "m1"), .init(label: "m2", enabled: false)]).node(),
            RadioGroup(options: ["a", "b"], selectedIndex: 1).node(),
            Tabs(titles: ["t1", "t2"], activeIndex: 0).node(),
            Dropdown(label: "d", options: ["a", "b"]).node(),
            TextField(label: "l", placeholder: "ph", text: "v").node(),
            TextArea(text: "line1\nline2").node(),
            Checkbox(label: "c", isChecked: true).node(id: "c"),
            CalendarView(year: 2026, month: 4).node(),
            Scrollbar(contentLength: 10, viewportSize: 5).node(),
            .spacer,
            .padding(.s, child: ch("x")),
            Block(title: "B").node(child: ch("y")),
            Node.vstack([ch("a"), Node.hstack([ch("b"), ch("c")])]),   // nested containers
            Form(fields: [.init(id: "f", label: "L", value: "v")]).node(),
        ]
        for node in samples { _ = renderer.view(for: node) }
        #expect(Bool(true))
    }
}
#endif
