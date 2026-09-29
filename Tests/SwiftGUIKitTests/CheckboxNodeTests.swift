// CheckboxNodeTests.swift
// SwiftGUIKit
// Phase 1 — Checkbox: exercises glyph(.check) via the SymbolSet.
// The box "[ ]" is the widget's own frame; the mark inside is the check symbol,
// so on the ASCII floor ("x") it reproduces the legacy "[x]" byte-for-byte, and
// on unicode it renders "[✓]". (Focus is deferred to the interaction phase.)

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Checkbox.node")
struct CheckboxNodeTests {

    @Test("node() carries checked state + label with default color role and empty id")
    func nodeDefaults() {
        #expect(Checkbox(label: "Remember me", isChecked: true).node()
                == .checkbox(isChecked: true, label: "Remember me", id: "", color: .label))
    }

    @Test("node() honors a chosen color role and interaction id")
    func nodeCustom() {
        #expect(Checkbox(label: "X", isChecked: false).node(id: "agree", color: .secondaryLabel)
                == .checkbox(isChecked: false, label: "X", id: "agree", color: .secondaryLabel))
    }
}

@Suite("Checkbox parity & glyphs")
struct CheckboxParityTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func rowText(_ buf: CellBuffer, width: Int) -> String {
        String((0..<width).map { buf[$0, 0].character })
    }

    @Test("ASCII floor reproduces the legacy unfocused checkbox byte-for-byte")
    func asciiParity() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalMono)
        for checked in [true, false] {
            for label in ["", "Remember me"] {
                var legacy = makeFrame(width: 40, height: 1)
                Checkbox(label: label, isChecked: checked).render(into: &legacy, focused: false)

                var node = makeFrame(width: 40, height: 1)
                renderer.render(Checkbox(label: label, isChecked: checked).node(), into: &node)

                for x in 0..<40 { #expect(legacy.cellBuffer[x, 0] == node.cellBuffer[x, 0]) }
            }
        }
    }

    @Test("unicode context renders the ✓ check glyph")
    func unicodeGlyph() {
        let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
        var frame = makeFrame(width: 20, height: 1)
        renderer.render(Checkbox(label: "OK", isChecked: true).node(), into: &frame)
        #expect(rowText(frame.cellBuffer, width: 20).hasPrefix("[✓] OK"))
    }

    @Test("a swapped-in SymbolSet changes the checkbox mark")
    func pluggableSymbolSet() {
        let custom = OverlaySymbolSet(base: DefaultSymbolSet(),
                                      overrides: [.check: GlyphMapping(sf: "checkmark", unicode: "✔", ascii: "X")])
        let renderer = CellRenderer(
            resolver: TerminalTokenResolver(theme: .dark, symbols: custom), context: .terminalTruecolor)
        var frame = makeFrame(width: 10, height: 1)
        renderer.render(Checkbox(isChecked: true).node(), into: &frame)
        #expect(rowText(frame.cellBuffer, width: 10).hasPrefix("[✔]"))
    }
}
