// TextReflowTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-07-03.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("TextReflow")
struct TextReflowTests {

    @Test("plainText strips ANSI escape sequences")
    func plainTextStrips() {
        let colored = "\u{001B}[32mhello\u{001B}[0m world"
        #expect(ANSIStringMetrics.plainText(colored) == "hello world")
    }

    @Test("plainText leaves plain input unchanged")
    func plainTextNoop() {
        #expect(ANSIStringMetrics.plainText("just text") == "just text")
    }

    @Test("unwrap joins consecutive non-blank lines with a single space")
    func unwrapJoins() {
        let lines = ["The quick brown fox", "jumps over the dog"]
        #expect(TextReflow.unwrap(lines) == "The quick brown fox jumps over the dog")
    }

    @Test("unwrap preserves paragraph breaks on blank lines")
    func unwrapParagraphs() {
        let lines = ["para one", "line two", "", "para two"]
        #expect(TextReflow.unwrap(lines) == "para one line two\n\npara two")
    }

    @Test("unwrap collapses multiple blank lines into a single paragraph break")
    func unwrapMultipleBlanks() {
        let lines = ["first", "", "", "", "second"]
        #expect(TextReflow.unwrap(lines) == "first\n\nsecond")
    }

    @Test("unwrap trims trailing whitespace before joining")
    func unwrapTrimsTrailing() {
        let lines = ["hello   ", "world"]
        #expect(TextReflow.unwrap(lines) == "hello world")
    }

    @Test("unwrap(rendered:) strips ANSI before joining")
    func unwrapRendered() {
        let lines = ["\u{001B}[1mbold line\u{001B}[0m", "continued"]
        #expect(TextReflow.unwrap(rendered: lines) == "bold line continued")
    }

    @Test("unwrap ignores leading and trailing blank lines")
    func unwrapEdgeBlanks() {
        let lines = ["", "content here", ""]
        #expect(TextReflow.unwrap(lines) == "content here")
    }

    @Test("unwrap of empty input yields empty string")
    func unwrapEmpty() {
        #expect(TextReflow.unwrap([]) == "")
    }
}
