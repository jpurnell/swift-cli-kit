// InlineGaugeTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-05-07.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("InlineGauge")
struct InlineGaugeTests {

    // MARK: - render tests

    @Test("Basic: half-filled gauge has correct fill counts and visible length")
    func basicHalfFilled() {
        let result = InlineGauge.render(current: 5, total: 10, width: 20)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 20)
        // Strip ANSI to count characters
        let stripped = stripANSI(result)
        let filledCount = stripped.filter { $0 == "\u{2588}" }.count
        let unfilledCount = stripped.filter { $0 == "\u{2591}" }.count
        #expect(filledCount == 10)
        #expect(unfilledCount == 10)
    }

    @Test("Full: completely filled gauge")
    func fullGauge() {
        let result = InlineGauge.render(current: 10, total: 10, width: 10)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 10)
        let stripped = stripANSI(result)
        let filledCount = stripped.filter { $0 == "\u{2588}" }.count
        let unfilledCount = stripped.filter { $0 == "\u{2591}" }.count
        #expect(filledCount == 10)
        #expect(unfilledCount == 0)
    }

    @Test("Empty: zero-filled gauge")
    func emptyGauge() {
        let result = InlineGauge.render(current: 0, total: 10, width: 10)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 10)
        let stripped = stripANSI(result)
        let filledCount = stripped.filter { $0 == "\u{2588}" }.count
        let unfilledCount = stripped.filter { $0 == "\u{2591}" }.count
        #expect(filledCount == 0)
        #expect(unfilledCount == 10)
    }

    @Test("Overflow clamped: current > total treated as full")
    func overflowClamped() {
        let result = InlineGauge.render(current: 15, total: 10, width: 10)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 10)
        let stripped = stripANSI(result)
        let filledCount = stripped.filter { $0 == "\u{2588}" }.count
        #expect(filledCount == 10)
    }

    @Test("Zero total: all unfilled")
    func zeroTotal() {
        let result = InlineGauge.render(current: 5, total: 0, width: 10)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 10)
        let stripped = stripANSI(result)
        let unfilledCount = stripped.filter { $0 == "\u{2591}" }.count
        #expect(unfilledCount == 10)
    }

    @Test("Zero width: returns empty string")
    func zeroWidth() {
        let result = InlineGauge.render(current: 5, total: 10, width: 0)
        #expect(result == "")
    }

    @Test("Width 1: single filled character at half ratio")
    func widthOne() {
        let result = InlineGauge.render(current: 1, total: 2, width: 1)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 1)
        let stripped = stripANSI(result)
        let filledCount = stripped.filter { $0 == "\u{2588}" }.count
        #expect(filledCount == 1)
    }

    @Test("Visible length invariant across various inputs")
    func visibleLengthInvariant() {
        let testCases: [(current: Int, total: Int, width: Int)] = [
            (0, 100, 40),
            (50, 100, 40),
            (100, 100, 40),
            (1, 3, 15),
            (7, 7, 1),
            (0, 0, 20),
            (999, 10, 30),
            (3, 10, 50),
        ]
        for tc in testCases {
            let result = InlineGauge.render(
                current: tc.current, total: tc.total, width: tc.width
            )
            let visible = ANSIStringMetrics.visibleLength(result)
            #expect(
                visible == tc.width,
                "Expected visible length \(tc.width) for current=\(tc.current), total=\(tc.total), width=\(tc.width), got \(visible)"
            )
        }
    }

    @Test("ANSI containment: result ends with reset escape")
    func ansiContainment() {
        let result = InlineGauge.render(current: 5, total: 10, width: 20)
        #expect(result.hasSuffix(ANSICodes.reset))
    }

    @Test("ANSI containment: empty string when width is zero has no dangling escapes")
    func ansiContainmentZeroWidth() {
        let result = InlineGauge.render(current: 5, total: 10, width: 0)
        #expect(!result.contains("\u{001B}"))
    }

    // MARK: - renderWithLabel tests

    @Test("renderWithLabel: visible length equals width")
    func renderWithLabelVisibleLength() {
        let result = InlineGauge.renderWithLabel(
            current: 50, total: 100, width: 30
        )
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 30)
    }

    @Test("renderWithLabel: contains percentage text")
    func renderWithLabelContainsPercentage() {
        let result = InlineGauge.renderWithLabel(
            current: 50, total: 100, width: 30
        )
        let stripped = stripANSI(result)
        #expect(stripped.contains("50%"))
    }

    @Test("renderWithLabel: full gauge shows 100%")
    func renderWithLabelFull() {
        let result = InlineGauge.renderWithLabel(
            current: 10, total: 10, width: 20
        )
        let stripped = stripANSI(result)
        #expect(stripped.contains("100%"))
    }

    @Test("renderWithLabel: empty gauge shows 0%")
    func renderWithLabelEmpty() {
        let result = InlineGauge.renderWithLabel(
            current: 0, total: 10, width: 20
        )
        let stripped = stripANSI(result)
        #expect(stripped.contains("0%"))
    }

    @Test("renderWithLabel: ends with reset escape")
    func renderWithLabelAnsiContainment() {
        let result = InlineGauge.renderWithLabel(
            current: 5, total: 10, width: 20
        )
        #expect(result.hasSuffix(ANSICodes.reset))
    }

    @Test("renderWithLabel: zero width returns empty string")
    func renderWithLabelZeroWidth() {
        let result = InlineGauge.renderWithLabel(
            current: 5, total: 10, width: 0
        )
        #expect(result == "")
    }

    @Test("Negative total: treated as all unfilled")
    func negativeTotal() {
        let result = InlineGauge.render(current: 5, total: -1, width: 10)
        let visible = ANSIStringMetrics.visibleLength(result)
        #expect(visible == 10)
        let stripped = stripANSI(result)
        let unfilledCount = stripped.filter { $0 == "\u{2591}" }.count
        #expect(unfilledCount == 10)
    }

    @Test("Custom colors are applied")
    func customColors() {
        let result = InlineGauge.render(
            current: 5, total: 10, width: 10,
            filledColor: .ansi8(.red),
            unfilledColor: .ansi8(.blue)
        )
        // Should contain the red foreground escape
        #expect(result.contains(ANSICodes.fg(.red)))
        // Should contain the blue foreground escape
        #expect(result.contains(ANSICodes.fg(.blue)))
    }

    @Test("Nil unfilled color uses dim escape")
    func nilUnfilledColorUsesDim() {
        let result = InlineGauge.render(
            current: 5, total: 10, width: 10,
            unfilledColor: nil
        )
        #expect(result.contains(ANSICodes.dim))
    }

    // MARK: - Helpers

    /// Strips ANSI escape sequences from a string for test assertions.
    private func stripANSI(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[[0-9;]*[A-Za-z]") else {
            return s
        }
        let range = NSRange(s.startIndex..., in: s)
        return regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    }
}
