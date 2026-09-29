// LayoutTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Layout")
struct LayoutTests {

    @Test("Fixed and percentage constraints produce correct widths")
    func fixedAndPercentage() throws {
        let area = Rect(x: 0, y: 0, width: 100, height: 24)
        let chunks = Layout.split(
            area: area,
            direction: .horizontal,
            constraints: [.fixed(20), .percentage(50), .fixed(30)]
        )
        try #require(chunks.count == 3)
        #expect(chunks[0].width == 20)
        #expect(chunks[1].width == 50)
        #expect(chunks[2].width == 30)
    }

    @Test("Ratio constraints divide space proportionally")
    func ratioConstraints() throws {
        let area = Rect(x: 0, y: 0, width: 120, height: 24)
        let chunks = Layout.split(
            area: area,
            direction: .horizontal,
            constraints: [.ratio(1, 3), .ratio(2, 3)]
        )
        try #require(chunks.count == 2)
        #expect(chunks[0].width == 40)
        #expect(chunks[1].width == 80)
    }

    @Test("Min and max constraints are clamped appropriately")
    func minMaxClamping() throws {
        // min(30) in a 20-wide area should not exceed the available space
        let smallArea = Rect(x: 0, y: 0, width: 20, height: 10)
        let small = Layout.split(area: smallArea, direction: .horizontal, constraints: [.min(30)])
        try #require(small.count == 1)
        #expect(small[0].width <= 20)

        // max(10) in a 50-wide area should cap at 10
        let bigArea = Rect(x: 0, y: 0, width: 50, height: 10)
        let big = Layout.split(area: bigArea, direction: .horizontal, constraints: [.max(10)])
        try #require(big.count == 1)
        #expect(big[0].width <= 10)
    }

    @Test("Zero-width rect produces no crash and zero-width results")
    func zeroWidthEdge() {
        let area = Rect(x: 0, y: 0, width: 0, height: 10)
        let chunks = Layout.split(area: area, direction: .horizontal, constraints: [.fixed(10)])
        // Should not crash; result widths should be zero
        for chunk in chunks {
            #expect(chunk.width == 0)
        }
    }

    @Test("Vertical split distributes heights correctly")
    func verticalSplit() throws {
        let area = Rect(x: 0, y: 0, width: 80, height: 24)
        let chunks = Layout.split(
            area: area,
            direction: .vertical,
            constraints: [.fixed(3), .percentage(50), .fixed(9)]
        )
        try #require(chunks.count == 3)
        #expect(chunks[0].height == 3)
        #expect(chunks[1].height == 12)
        #expect(chunks[2].height == 9)
    }

    @Test("Constraints exceeding available space give zero to overflow items")
    func overflow() throws {
        let area = Rect(x: 0, y: 0, width: 30, height: 10)
        let chunks = Layout.split(
            area: area,
            direction: .horizontal,
            constraints: [.fixed(20), .fixed(20)]
        )
        try #require(chunks.count == 2)
        #expect(chunks[0].width == 20)
        #expect(chunks[1].width == 0, "Second chunk should get zero when space is exhausted")
    }

    @Test("Three fixed constraints totalling more than available space: third gets zero width")
    func constraintOverflow() throws {
        let area = Rect(x: 0, y: 0, width: 100, height: 1)
        let chunks = Layout.split(
            area: area,
            direction: .horizontal,
            constraints: [.fixed(50), .fixed(50), .fixed(50)]
        )
        try #require(chunks.count == 3)
        // First two should fit (50 + 50 = 100)
        #expect(chunks[0].width == 50)
        #expect(chunks[1].width == 50)
        // Third has no remaining space — should get 0, not negative or crash
        #expect(chunks[2].width == 0)
        // All widths must be non-negative
        for chunk in chunks {
            #expect(chunk.width >= 0, "No rect should have negative width")
        }
    }
}
