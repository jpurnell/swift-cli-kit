// LineEditorTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("LineEditor")
struct LineEditorTests {

    private func feedKeys(_ editor: inout LineEditor, _ keys: [Key]) -> LineResult {
        var result: LineResult = .editing
        for key in keys {
            result = editor.handleKey(key)
        }
        return result
    }

    private func characterKeys(_ s: String) -> [Key] {
        s.map { .character($0) }
    }

    @Test("Type hello and press enter completes")
    func typeAndEnter() {
        var editor = LineEditor()
        let result = feedKeys(&editor, characterKeys("hello") + [.enter])
        #expect(result == .completed("hello"))
    }

    @Test("Backspace corrects a typo")
    func backspace() {
        var editor = LineEditor()
        let result = feedKeys(&editor, characterKeys("helo") + [.backspace] + characterKeys("lo") + [.enter])
        #expect(result == .completed("hello"))
    }

    @Test("Arrow left then insert character at cursor position")
    func arrowLeftInsert() {
        var editor = LineEditor()
        let keys: [Key] = characterKeys("hllo")
            + [.arrowLeft, .arrowLeft, .arrowLeft]
            + characterKeys("e")
            + [.enter]
        let result = feedKeys(&editor, keys)
        #expect(result == .completed("hello"))
    }

    @Test("Home jumps cursor to start")
    func homeJump() {
        var editor = LineEditor()
        let result = feedKeys(&editor, characterKeys("abc") + [.home] + characterKeys("X") + [.enter])
        #expect(result == .completed("Xabc"))
    }

    @Test("End jumps cursor to end")
    func endJump() {
        var editor = LineEditor()
        let result = feedKeys(&editor, characterKeys("abc") + [.home, .end] + characterKeys("X") + [.enter])
        #expect(result == .completed("abcX"))
    }

    @Test("Ctrl-A moves cursor to position 0")
    func ctrlAIsHome() {
        var editor = LineEditor()
        _ = feedKeys(&editor, characterKeys("abc") + [.ctrlA])
        #expect(editor.cursorPosition == 0)
    }

    @Test("Ctrl-E moves cursor to end of text")
    func ctrlEIsEnd() {
        var editor = LineEditor()
        _ = feedKeys(&editor, characterKeys("abc") + [.ctrlE])
        #expect(editor.cursorPosition == 3)
    }

    @Test("Ctrl-K kills text from cursor to end of line")
    func ctrlKKillToEnd() {
        var editor = LineEditor()
        let result = feedKeys(&editor, characterKeys("hello") + [.arrowLeft, .arrowLeft, .ctrlK, .enter])
        #expect(result == .completed("hel"))
    }

    @Test("Ctrl-W deletes previous word")
    func ctrlWDeleteWord() {
        var editor = LineEditor()
        let result = feedKeys(&editor, characterKeys("hello world") + [.ctrlW, .enter])
        #expect(result == .completed("hello "))
    }

    @Test("Ctrl-U kills text from cursor to start of line")
    func ctrlUKillToStart() {
        var editor = LineEditor()
        _ = feedKeys(&editor, characterKeys("hello") + [.ctrlU])
        #expect(editor.text == "")
        #expect(editor.cursorPosition == 0)
    }

    @Test("Ctrl-D on empty editor returns EOF")
    func ctrlDOnEmpty() {
        var editor = LineEditor()
        let result = editor.handleKey(.ctrlD)
        #expect(result == .eof)
    }

    @Test("Ctrl-D on non-empty editor stays in editing mode")
    func ctrlDOnNonEmpty() {
        var editor = LineEditor()
        _ = feedKeys(&editor, characterKeys("abc"))
        let result = editor.handleKey(.ctrlD)
        #expect(result == .editing)
    }

    @Test("Ctrl-C sends interrupt")
    func ctrlCInterrupt() {
        var editor = LineEditor()
        _ = feedKeys(&editor, characterKeys("abc"))
        let result = editor.handleKey(.ctrlC)
        #expect(result == .interrupt)
    }

    @Test("Multi-byte character cursor movement treats emoji as one grapheme")
    func multiByteCharCursorMovement() {
        var editor = LineEditor()
        // Type emoji, arrow left over it, insert X before it, then enter
        let keys: [Key] = [.character("\u{1F600}"), .arrowLeft, .character("X"), .enter]
        let result = feedKeys(&editor, keys)
        #expect(result == .completed("X\u{1F600}"))
    }

    @Test("Arrow keys respect boundaries: no overflow or underflow")
    func arrowBoundaries() {
        var editor = LineEditor()
        _ = feedKeys(&editor, characterKeys("ab"))

        // Arrow right past end should stay at 2
        _ = editor.handleKey(.arrowRight)
        _ = editor.handleKey(.arrowRight)
        #expect(editor.cursorPosition == 2)

        // Create fresh editor: arrow left on empty stays at 0
        var emptyEditor = LineEditor()
        _ = emptyEditor.handleKey(.arrowLeft)
        #expect(emptyEditor.cursorPosition == 0)
    }
}
