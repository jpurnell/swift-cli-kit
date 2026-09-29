// StatusAreaTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("StatusArea")
struct StatusAreaTests {

    @Test("Push one message and render returns it")
    func pushOne() {
        let area = StatusArea()
        area.push("hello")
        let lines = area.render(width: 40, colorize: false)
        #expect(lines.count == 1)
        #expect(lines.first?.contains("hello") == true)
    }

    @Test("Push beyond max evicts oldest messages")
    func pushOverflow() {
        let area = StatusArea(maxMessages: 5)
        for i in 0..<6 {
            area.push("msg\(i)")
        }
        let lines = area.render(width: 40, colorize: false)
        #expect(lines.count == 5)
        let joined = lines.joined()
        #expect(!joined.contains("msg0"))
    }

    @Test("Clear removes all messages")
    func clear() {
        let area = StatusArea()
        area.push("a")
        area.clear()
        let lines = area.render(width: 40, colorize: false)
        #expect(lines.isEmpty)
    }

    @Test("lineCount reflects number of messages")
    func lineCount() {
        let area = StatusArea()
        area.push("a")
        area.push("b")
        area.push("c")
        #expect(area.lineCount == 3)
    }

    @Test("Concurrent pushes do not crash")
    func threadSafety() {
        let area = StatusArea()
        DispatchQueue.concurrentPerform(iterations: 10) { i in
            area.push("msg\(i)")
        }
        #expect(area.lineCount <= 10)
    }

    @Test("Render with colorize true includes ANSI escape codes")
    func renderColorize() {
        let area = StatusArea()
        area.push("err")
        let lines = area.render(width: 40, colorize: true)
        #expect(lines.first?.contains("\u{001B}[") == true)
    }

    @Test("Render with colorize false excludes ANSI escape codes")
    func renderNoColorize() {
        let area = StatusArea()
        area.push("err")
        let lines = area.render(width: 40, colorize: false)
        #expect(lines.first?.contains("\u{001B}[") != true)
    }
}
