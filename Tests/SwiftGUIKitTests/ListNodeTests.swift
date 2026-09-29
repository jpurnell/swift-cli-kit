// ListNodeTests.swift
// SwiftGUIKit
// Phase 1 — List: the first stateful widget. Selection/scroll are data in the
// node (no Message generic); the highlight is the `.focused` WidgetState token.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("List.node")
struct ListNodeTests {

    @Test("node() carries item texts + selection/scroll state, dropping per-item styles")
    func nodeDefaults() {
        let list = List(items: [.init(text: "A"), .init(text: "B")], state: ListState(selectedIndex: 0))
        #expect(list.node() == .list(items: ["A", "B"], selectedIndex: 0, scrollOffset: 0,
                                     itemColor: .label, showScrollbar: false, id: ""))
    }

    @Test("node() carries scrollOffset, showScrollbar, and a chosen item color role")
    func nodeCustom() {
        let list = List(items: [.init(text: "X")], state: ListState(selectedIndex: nil, scrollOffset: 3),
                        showScrollbar: true)
        #expect(list.node(itemColor: .secondaryLabel) == .list(items: ["X"], selectedIndex: nil,
                                                               scrollOffset: 3, itemColor: .secondaryLabel,
                                                               showScrollbar: true, id: ""))
    }
}

@Suite("List parity (token→node→cell == legacy)")
struct ListParityTests {

    private let resolver = TerminalTokenResolver(theme: .dark)
    private let ctx = DesignContext.terminalTruecolor

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height {
            for x in 0..<width where a[x, y] != b[x, y] { return false }
        }
        return true
    }

    @Test("parity across items × selection × scroll × size, incl. overflow & out-of-range selection")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: resolver, context: ctx)
        let role = ColorRole.label

        // The styles the token path will produce — used to configure the legacy list.
        let base = resolver.color(role, in: ctx)
        let normal = CellStyle(fg: base.color, bg: .default, attributes: base.attributes)
        let focusAttrs = resolver.style(for: .focused, in: ctx).attributes
        let highlight = CellStyle(fg: base.color, bg: .default, attributes: base.attributes.union(focusAttrs))

        let datasets: [[String]] = [[], ["Alpha"], ["Alpha", "Beta", "Gamma"],
                                    ["a very long item that overflows narrow frames", "short"]]
        for texts in datasets {
            for selected in [Int?.none, 0, 1, 99] {
                for scrollOffset in [0, 1] {
                    for (width, height) in [(1, 1), (10, 3), (20, 10)] {
                        for showScrollbar in [false, true] {
                            let list = List(
                                items: texts.map { List.Item(text: $0, style: normal) },
                                state: ListState(selectedIndex: selected, scrollOffset: scrollOffset),
                                highlightStyle: highlight,
                                showScrollbar: showScrollbar)

                            var legacyFrame = makeFrame(width: width, height: height)
                            list.render(into: &legacyFrame)

                            var nodeFrame = makeFrame(width: width, height: height)
                            renderer.render(list.node(itemColor: role), into: &nodeFrame)

                            #expect(gridsEqual(legacyFrame.cellBuffer, nodeFrame.cellBuffer, width: width, height: height),
                                    "mismatch texts=\(texts.count) sel=\(String(describing: selected)) scroll=\(scrollOffset) \(width)x\(height)")
                        }
                    }
                }
            }
        }
    }
}
