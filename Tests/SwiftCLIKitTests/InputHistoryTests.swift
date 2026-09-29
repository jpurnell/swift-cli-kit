// InputHistoryTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("InputHistory")
struct InputHistoryTests {

    @Test("Add entries and navigate up returns most recent first")
    func addAndNavigateUp() {
        var history = InputHistory()
        history.add("a")
        history.add("b")
        history.add("c")

        #expect(history.navigateUp(current: "") == "c")
        #expect(history.navigateUp(current: "") == "b")
        #expect(history.navigateUp(current: "") == "a")
    }

    @Test("Navigate down after going up returns forward through history")
    func navigateDown() {
        var history = InputHistory()
        history.add("a")
        history.add("b")
        history.add("c")

        _ = history.navigateUp(current: "stashed")
        _ = history.navigateUp(current: "")
        _ = history.navigateUp(current: "")

        #expect(history.navigateDown() == "b")
        #expect(history.navigateDown() == "c")
        #expect(history.navigateDown() == "stashed")
    }

    @Test("Navigate down past bottom returns stashed current text")
    func downPastBottom() {
        var history = InputHistory()
        history.add("a")
        _ = history.navigateUp(current: "typed")
        // Now at "a", go down to stashed
        let result = history.navigateDown()
        #expect(result == "typed")
    }

    @Test("Navigate up past top returns nil")
    func upPastTop() {
        var history = InputHistory()
        history.add("only")

        #expect(history.navigateUp(current: "") == "only")
        #expect(history.navigateUp(current: "") == nil)
    }

    @Test("Consecutive duplicates are collapsed to one entry")
    func consecutiveDuplicates() {
        var history = InputHistory()
        history.add("a")
        history.add("a")

        #expect(history.navigateUp(current: "") == "a")
        #expect(history.navigateUp(current: "") == nil)
    }

    @Test("Empty string is not added to history")
    func emptyString() {
        var history = InputHistory()
        history.add("")

        #expect(history.navigateUp(current: "") == nil)
    }

    @Test("Max entries enforced: oldest entry evicted beyond limit")
    func maxEntries() {
        var history = InputHistory(maxEntries: 100)
        for i in 0...100 {
            history.add("entry\(i)")
        }

        // Navigate all the way up to the oldest
        var entries: [String] = []
        while let entry = history.navigateUp(current: "") {
            entries.append(entry)
        }

        #expect(!entries.contains("entry0"))
        #expect(entries.contains("entry1"))
    }

    @Test("Reset clears navigation index but preserves entries")
    func reset() {
        var history = InputHistory()
        history.add("a")
        history.add("b")
        _ = history.navigateUp(current: "current")

        history.reset()

        // After reset, navigateUp should start from the top again
        #expect(history.navigateUp(current: "current") == "b")
    }
}
