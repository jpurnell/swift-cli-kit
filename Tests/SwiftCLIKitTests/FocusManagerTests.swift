// FocusManagerTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("FocusManager")
struct FocusManagerTests {

    @Test("Tab cycles focus forward through all IDs and wraps")
    func tabCyclesFocus() {
        var fm = FocusManager(focusOrder: ["a", "b", "c"])
        #expect(fm.focused == "a")
        fm.focusNext()
        #expect(fm.focused == "b")
        fm.focusNext()
        #expect(fm.focused == "c")
        fm.focusNext()
        #expect(fm.focused == "a")  // wrap
    }

    @Test("Shift-tab reverses focus and wraps to last")
    func shiftTabReverses() {
        var fm = FocusManager(focusOrder: ["a", "b", "c"])
        #expect(fm.focused == "a")
        fm.focusPrevious()
        #expect(fm.focused == "c")  // wrap to last
    }

    @Test("Focus a specific ID by name")
    func focusSpecificID() {
        var fm = FocusManager(focusOrder: ["a", "b", "c"])
        fm.focus("b")
        #expect(fm.isFocused("b") == true)
        #expect(fm.isFocused("a") == false)
    }

    @Test("Focusing an unknown ID leaves focus unchanged")
    func unknownID() {
        var fm = FocusManager(focusOrder: ["a", "b", "c"])
        let before = fm.focused
        fm.focus("nonexistent")
        #expect(fm.focused == before)
    }

    @Test("Blur removes focus from all elements")
    func blur() {
        var fm = FocusManager(focusOrder: ["a", "b", "c"])
        fm.blur()
        #expect(fm.focused == nil)
        #expect(fm.isFocused("a") == false)
        #expect(fm.isFocused("b") == false)
        #expect(fm.isFocused("c") == false)
    }

    @Test("Empty focus order does not crash")
    func emptyFocusOrder() {
        var fm = FocusManager(focusOrder: [])
        #expect(fm.focused == nil)
        fm.focusNext()
        #expect(fm.focused == nil)
        fm.focusPrevious()
        #expect(fm.focused == nil)
    }

    @Test("Focus skips removed element without crashing")
    func focusSkipsRemoved() {
        var fm = FocusManager(focusOrder: ["a", "b", "c"])
        fm.focus("b")
        #expect(fm.focused == "b")
        // Shrink focusOrder so index 1 now points at "c", and index 2 is out of bounds
        fm.focusOrder = ["a", "c"]
        // The retained index 1 is still in bounds, and now addresses "c".
        #expect(fm.focused == "c")
        // From index 1 of a two-element ring, the next element wraps to the first.
        fm.focusNext()
        #expect(fm.focused == "a")
    }

    @Test("After blur, focusNext re-enters ring from the start")
    func emptyAfterBlur() {
        var fm = FocusManager(focusOrder: ["a", "b"])
        fm.blur()
        #expect(fm.focused == nil)
        fm.focusNext()
        #expect(fm.focused == "a")
    }
}
