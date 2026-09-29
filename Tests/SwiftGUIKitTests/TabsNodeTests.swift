// TabsNodeTests.swift
// SwiftGUIKit
// Phase 1 — Tabs: a clean byte-parity port. The active tab is bold, which maps
// to font(.heading); inactive tabs are font(.body). These equal the legacy
// default styles, so the tokenized render matches legacy byte-for-byte.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Tabs.node")
struct TabsNodeTests {

    @Test("node() carries titles/active/separator/underline with default color role")
    func nodeDefaults() {
        #expect(Tabs(titles: ["Home", "About"], activeIndex: 1).node()
                == .tabs(titles: ["Home", "About"], activeIndex: 1, separator: " | ", underline: nil, id: "", color: .label))
    }

    @Test("node() carries a custom separator, underline, and color role")
    func nodeCustom() {
        #expect(Tabs(titles: ["A"], separator: " · ", underline: "─").node(color: .secondaryLabel)
                == .tabs(titles: ["A"], activeIndex: 0, separator: " · ", underline: "─", id: "", color: .secondaryLabel))
    }
}

@Suite("Tabs parity (token→node→cell == legacy)")
struct TabsParityTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    @Test("parity across titles × active × separator × underline × size")
    func parityMatrix() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)

        let titleSets: [[String]] = [[], ["Home"], ["Home", "Settings", "About"]]
        for titles in titleSets {
            for active in [0, 1, 5] {
                for separator in [" | ", " · "] {
                    for underline in [Character?.none, "─"] {
                        for (width, height) in [(10, 1), (40, 2)] {
                            let tabs = Tabs(titles: titles, activeIndex: active, separator: separator, underline: underline)

                            var legacy = makeFrame(width: width, height: height)
                            tabs.render(into: &legacy)

                            var node = makeFrame(width: width, height: height)
                            renderer.render(tabs.node(), into: &node)

                            #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: width, height: height),
                                    "mismatch titles=\(titles) active=\(active) sep=\(separator) ul=\(String(describing: underline)) \(width)x\(height)")
                        }
                    }
                }
            }
        }
    }
}
