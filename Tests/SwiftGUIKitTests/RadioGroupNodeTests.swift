// RadioGroupNodeTests.swift
// SwiftGUIKit
// Phase 1 — RadioGroup: exercises glyph(.radioOn)/glyph(.radioOff).
// The parens "( )" are the widget's frame; the mark is a radio symbol. This is
// the first INTENTIONAL divergence from legacy: the unselected option renders an
// open circle "○" (clearer) rather than legacy's empty "( )". The selected row
// still matches legacy byte-for-byte in a unicode context.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("RadioGroup.node")
struct RadioGroupNodeTests {

    @Test("node() carries options + selection with default color role")
    func nodeDefaults() {
        #expect(RadioGroup(options: ["A", "B"], selectedIndex: 1).node()
                == .radioGroup(options: ["A", "B"], selectedIndex: 1, id: "", color: .label))
    }

    @Test("node() honors a chosen color role")
    func nodeCustom() {
        #expect(RadioGroup(options: ["X"]).node(color: .secondaryLabel)
                == .radioGroup(options: ["X"], selectedIndex: 0, id: "", color: .secondaryLabel))
    }
}

@Suite("RadioGroup glyphs & selected-row parity")
struct RadioGroupRenderTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func rowText(_ buf: CellBuffer, width: Int, y: Int) -> String {
        String((0..<width).map { buf[$0, y].character })
    }

    private func render(_ node: Node, ctx: DesignContext, width: Int, height: Int) -> CellBuffer {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: ctx)
        var frame = makeFrame(width: width, height: height)
        renderer.render(node, into: &frame)
        return frame.cellBuffer
    }

    @Test("unicode: filled ● for selected, open ○ for the rest")
    func unicodeGlyphs() {
        let buf = render(RadioGroup(options: ["Small", "Medium", "Large"], selectedIndex: 1).node(),
                         ctx: .terminalTruecolor, width: 12, height: 3)
        #expect(rowText(buf, width: 12, y: 0).hasPrefix("(○) Small"))
        #expect(rowText(buf, width: 12, y: 1).hasPrefix("(●) Medium"))
        #expect(rowText(buf, width: 12, y: 2).hasPrefix("(○) Large"))
    }

    @Test("ascii floor uses bare radio marks inside the widget's parens")
    func asciiGlyphs() {
        let buf = render(RadioGroup(options: ["A", "B"], selectedIndex: 0).node(),
                         ctx: .terminalMono, width: 6, height: 2)
        #expect(rowText(buf, width: 6, y: 0).hasPrefix("(*) A"))
        #expect(rowText(buf, width: 6, y: 1).hasPrefix("(o) B"))
    }

    @Test("the selected row matches the legacy renderer byte-for-byte (unicode)")
    func selectedRowParity() {
        let group = RadioGroup(options: ["Small", "Medium", "Large"], selectedIndex: 1)
        var legacy = makeFrame(width: 20, height: 3)
        group.render(into: &legacy, focused: false)
        let node = render(group.node(), ctx: .terminalTruecolor, width: 20, height: 3)
        for x in 0..<20 { #expect(legacy.cellBuffer[x, 1] == node[x, 1]) } // row 1 = selected
    }

    @Test("a swapped-in SymbolSet changes the selected radio mark")
    func pluggableSymbolSet() {
        let custom = OverlaySymbolSet(base: DefaultSymbolSet(),
                                      overrides: [.radioOn: GlyphMapping(sf: "largecircle.fill.circle", unicode: "◉", ascii: "@")])
        let renderer = CellRenderer(
            resolver: TerminalTokenResolver(theme: .dark, symbols: custom), context: .terminalTruecolor)
        var frame = makeFrame(width: 8, height: 1)
        renderer.render(RadioGroup(options: ["A"], selectedIndex: 0).node(), into: &frame)
        #expect(rowText(frame.cellBuffer, width: 8, y: 0).hasPrefix("(◉) A"))
    }
}
