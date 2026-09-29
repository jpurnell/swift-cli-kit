// MenuNodeTests.swift
// SwiftGUIKit
// Phase 1 — Menu: byte-parity for the visible rows, PLUS a genuine overflow "…"
// indicator (via glyph(.overflow)) when items exceed the frame height — a real
// UX improvement over the legacy widget, which truncates silently.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Menu.node")
struct MenuNodeTests {

    @Test("node() carries items (label/keyHint/enabled) + selection")
    func nodeDefaults() {
        let menu = Menu(items: [.init(label: "New", keyHint: "Ctrl+N"), .init(label: "Off", enabled: false)],
                        selectedIndex: 0)
        #expect(menu.node() == .menu(items: [
            MenuEntry(label: "New", keyHint: "Ctrl+N", enabled: true),
            MenuEntry(label: "Off", keyHint: nil, enabled: false),
        ], selectedIndex: 0, id: "", color: .label))
    }
}

@Suite("Menu parity & overflow")
struct MenuRenderTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    private func rowText(_ buf: CellBuffer, width: Int, y: Int) -> String {
        String((0..<width).map { buf[$0, y].character })
    }

    @Test("visible rows byte-match the legacy default menu (no overflow)")
    func visibleParity() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
        let items = [
            Menu.MenuItem(label: "New File", keyHint: "Ctrl+N"),
            Menu.MenuItem(label: "Open", keyHint: "Ctrl+O"),
            Menu.MenuItem(label: "Disabled", enabled: false),
        ]
        for selected in [0, 1, 2] {
            for (width, height) in [(20, 3), (30, 5)] {   // height >= items.count → no truncation
                let menu = Menu(items: items, selectedIndex: selected)
                var legacy = makeFrame(width: width, height: height)
                menu.render(into: &legacy)
                var node = makeFrame(width: width, height: height)
                renderer.render(menu.node(), into: &node)
                #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: width, height: height),
                        "mismatch selected=\(selected) \(width)x\(height)")
            }
        }
    }

    @Test("overflow row shows the … glyph when items exceed height")
    func overflowIndicator() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
        let items = (1...6).map { Menu.MenuItem(label: "Item \($0)") }
        var frame = makeFrame(width: 12, height: 3)   // 6 items, 3 rows → truncated
        renderer.render(Menu(items: items, selectedIndex: 0).node(), into: &frame)
        // Rows 0,1 are items; row 2 is the overflow indicator.
        #expect(rowText(frame.cellBuffer, width: 12, y: 0).hasPrefix("Item 1"))
        #expect(rowText(frame.cellBuffer, width: 12, y: 1).hasPrefix("Item 2"))
        #expect(rowText(frame.cellBuffer, width: 12, y: 2).hasPrefix("…"))
    }

    @Test("ascii overflow uses the … ascii fallback")
    func overflowAscii() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalMono)
        let items = (1...4).map { Menu.MenuItem(label: "x\($0)") }
        var frame = makeFrame(width: 8, height: 2)
        renderer.render(Menu(items: items, selectedIndex: 0).node(), into: &frame)
        #expect(rowText(frame.cellBuffer, width: 8, y: 1).hasPrefix("..."))
    }
}
