// CommandPaletteTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Command Palette")
struct CommandPaletteTests {

    // MARK: - FuzzyMatcher

    @Test("FuzzyMatcher exact match scores highest")
    func exactMatchScoresHighest() throws {
        let exact = try #require(FuzzyMatcher.score("Save", against: "Save"))
        let prefix = try #require(FuzzyMatcher.score("Sav", against: "Save"))
        let subsequence = try #require(FuzzyMatcher.score("Sv", against: "Save"))

        #expect(exact == 19)   // exactMatchBonus(10) + prefixBonus(5) + 4*perChar(1)
        #expect(prefix == 12)  // prefixBonus(5) + 3*perChar(1) + 2*consecutiveBonus(2)
        #expect(subsequence == 2) // 2*perChar(1), no bonuses

        #expect(exact > prefix, "Exact match should score higher than prefix")
        #expect(prefix > subsequence, "Prefix should score higher than scattered subsequence")
    }

    @Test("FuzzyMatcher prefix beats subsequence")
    func prefixBeatsSubsequence() throws {
        let prefix = try #require(FuzzyMatcher.score("Sav", against: "Save File"))
        let subsequence = try #require(FuzzyMatcher.score("SFi", against: "Save File"))

        #expect(prefix == 12)     // prefixBonus(5) + 3*perChar(1) + 2*consecutiveBonus(2)
        #expect(subsequence == 5) // 3*perChar(1) + 1*consecutiveBonus(2)

        #expect(prefix > subsequence, "Prefix match should rank above scattered subsequence")
    }

    @Test("FuzzyMatcher no match returns nil")
    func noMatchReturnsNil() {
        let result = FuzzyMatcher.score("xyz", against: "Save File")
        #expect(result == nil)
    }

    @Test("FuzzyMatcher case insensitive matching")
    func caseInsensitive() throws {
        let result = try #require(FuzzyMatcher.score("save", against: "Save File"))
        #expect(result > 0, "Case-insensitive match should produce a positive score")
    }

    @Test("FuzzyMatcher empty query matches everything with zero score")
    func emptyQueryMatchesAll() {
        let result = FuzzyMatcher.score("", against: "Anything")
        #expect(result == 0)
    }

    // MARK: - PaletteRegistry

    @Test("PaletteRegistry register and search finds action")
    func registerAndSearch() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "save", label: "Save File"))
        registry.register(PaletteAction(id: "open", label: "Open File"))
        registry.register(PaletteAction(id: "close", label: "Close Tab"))

        let results = registry.search(query: "file")
        #expect(results.count == 2)
        #expect(results.contains { $0.id == "save" })
        #expect(results.contains { $0.id == "open" })
    }

    @Test("PaletteRegistry unregister removes action")
    func unregisterRemovesAction() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "save", label: "Save File"))
        registry.register(PaletteAction(id: "open", label: "Open File"))

        registry.unregister(id: "save")

        let results = registry.search(query: "")
        #expect(results.count == 1)
        #expect(results[0].id == "open")
    }

    @Test("PaletteRegistry empty query returns all sorted by label")
    func emptyQueryReturnsAll() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "b", label: "Banana"))
        registry.register(PaletteAction(id: "a", label: "Apple"))
        registry.register(PaletteAction(id: "c", label: "Cherry"))

        let results = registry.search(query: "")
        #expect(results.count == 3)
        #expect(results[0].label == "Apple")
        #expect(results[1].label == "Banana")
        #expect(results[2].label == "Cherry")
    }

    // MARK: - CommandPalette

    @Test("CommandPalette updateQuery filters results")
    func updateQueryFiltersResults() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "save", label: "Save File"))
        registry.register(PaletteAction(id: "open", label: "Open File"))
        registry.register(PaletteAction(id: "quit", label: "Quit"))

        var palette = CommandPalette(registry: registry)
        palette.show()
        palette.updateQuery("file")

        #expect(palette.results.count == 2)
        #expect(palette.results.allSatisfy { $0.label.lowercased().contains("file") })
    }

    @Test("CommandPalette selectNext and selectPrevious cycle correctly")
    func selectNextPreviousCycles() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "a", label: "Alpha"))
        registry.register(PaletteAction(id: "b", label: "Beta"))
        registry.register(PaletteAction(id: "c", label: "Charlie"))

        var palette = CommandPalette(registry: registry)
        palette.show()

        #expect(palette.selectedIndex == 0)
        palette.selectNext()
        #expect(palette.selectedIndex == 1)
        palette.selectNext()
        #expect(palette.selectedIndex == 2)
        // Wrap around
        palette.selectNext()
        #expect(palette.selectedIndex == 0)

        // Previous wraps from 0 to end
        palette.selectPrevious()
        #expect(palette.selectedIndex == 2)
    }

    @Test("CommandPalette selectedAction returns nil for empty results")
    func selectedActionNilWhenEmpty() {
        var palette = CommandPalette()
        palette.show()
        palette.updateQuery("nonexistent_xyz")
        #expect(palette.selectedAction == nil)
    }

    @Test("CommandPalette render shows query and results")
    func renderShowsContent() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "save", label: "Save File"))

        var palette = CommandPalette(registry: registry)
        palette.show()
        palette.updateQuery("sav")

        let buf = CellBuffer(width: 80, height: 24)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: 80, height: 24))
        palette.render(into: &frame)

        // The palette should have written non-empty cells somewhere in the frame
        let result = frame.cellBuffer
        var nonEmptyCount = 0
        for y in 0..<24 {
            for x in 0..<80 {
                if result[x, y] != .empty {
                    nonEmptyCount += 1
                }
            }
        }
        #expect(nonEmptyCount > 0, "Visible palette should render non-empty cells")
    }

    @Test("CommandPalette hide makes render a no-op")
    func hideRendersNothing() {
        var registry = PaletteRegistry()
        registry.register(PaletteAction(id: "save", label: "Save File"))

        var palette = CommandPalette(registry: registry)
        palette.hide()

        let buf = CellBuffer(width: 80, height: 24)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: 80, height: 24))
        palette.render(into: &frame)

        let result = frame.cellBuffer
        var nonEmptyCount = 0
        for y in 0..<24 {
            for x in 0..<80 {
                if result[x, y] != .empty {
                    nonEmptyCount += 1
                }
            }
        }
        #expect(nonEmptyCount == 0, "Hidden palette should not write any cells")
    }
}
