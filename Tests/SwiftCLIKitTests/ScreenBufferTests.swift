// ScreenBufferTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("ScreenBuffer")
struct ScreenBufferTests {

    @Test("Empty buffer has empty raw and frame starts with clear+home")
    func emptyBuffer() {
        let buf = ScreenBuffer(width: 80)
        #expect(buf.raw == "")
        #expect(buf.frame.hasPrefix("\u{001B}[2J\u{001B}[H"))
    }

    @Test("appendLine adds text followed by newline")
    func appendLine() {
        var buf = ScreenBuffer(width: 80)
        buf.appendLine("hello")
        #expect(buf.raw.contains("hello\n"))
    }

    @Test("append adds text without trailing newline")
    func appendNoNewline() {
        var buf = ScreenBuffer(width: 80)
        buf.append("hi")
        #expect(buf.raw == "hi")
        #expect(!buf.raw.contains("\n"))
    }

    @Test("Multiple appendLine calls preserve order")
    func multipleLines() throws {
        var buf = ScreenBuffer(width: 80)
        buf.appendLine("a")
        buf.appendLine("b")
        let raw = buf.raw
        let rangeA = try #require(raw.range(of: "a\n"))
        let rangeB = try #require(raw.range(of: "b\n"))
        #expect(rangeA.lowerBound < rangeB.lowerBound)
    }

    @Test("frame includes clear screen and home prefix")
    func frameIncludesPrefix() {
        var buf = ScreenBuffer(width: 80)
        buf.appendLine("x")
        #expect(buf.frame.hasPrefix("\u{001B}[2J\u{001B}[H"))
    }

    @Test("raw excludes clear screen escape")
    func rawExcludesPrefix() {
        var buf = ScreenBuffer(width: 80)
        buf.appendLine("x")
        #expect(!buf.raw.contains("\u{001B}[2J"))
    }
}
