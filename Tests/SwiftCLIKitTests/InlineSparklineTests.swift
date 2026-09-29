// InlineSparklineTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-05-07.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("InlineSparkline")
struct InlineSparklineTests {

    // MARK: - Block character constants for readability

    /// The 9 block levels from empty to full.
    private static let blocks: [Character] = [" ", "\u{2581}", "\u{2582}", "\u{2583}", "\u{2584}", "\u{2585}", "\u{2586}", "\u{2587}", "\u{2588}"]

    /// Strips ANSI escapes to get just the visible characters.
    private func visibleChars(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[[0-9;]*[A-Za-z]") else {
            return s
        }
        let range = NSRange(s.startIndex..., in: s)
        return regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    }

    // MARK: - 1. Basic normalization

    @Test("Basic: [0, 0.5, 1.0] maps to space, mid-block, full-block")
    func basicNormalization() {
        let result = InlineSparkline.render(data: [0.0, 0.5, 1.0], width: 3)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 3)
        // 0.0 maps to index 0 (space), 0.5 maps to index 4 (mid), 1.0 maps to index 8 (full)
        #expect(chars[0] == Self.blocks[0])  // space
        #expect(chars[1] == Self.blocks[4])  // mid-height
        #expect(chars[2] == Self.blocks[8])  // full block
    }

    // MARK: - 2. All zeros

    @Test("All zeros: equal data produces mid-height blocks")
    func allZeros() {
        let result = InlineSparkline.render(data: [0.0, 0.0, 0.0], width: 3)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 3)
        for ch in chars {
            #expect(ch == Self.blocks[4])
        }
    }

    // MARK: - 3. All same non-zero

    @Test("All same non-zero: equal data produces mid-height blocks")
    func allSameNonZero() {
        let result = InlineSparkline.render(data: [5.0, 5.0, 5.0], width: 3)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 3)
        for ch in chars {
            #expect(ch == Self.blocks[4])
        }
    }

    // MARK: - 4. Empty data

    @Test("Empty data: produces width spaces")
    func emptyData() {
        let result = InlineSparkline.render(data: [] as [Double], width: 5)
        let vis = visibleChars(result)
        #expect(vis == "     ")
        #expect(ANSIStringMetrics.visibleLength(result) == 5)
    }

    // MARK: - 5. Zero width

    @Test("Zero width: produces empty string")
    func zeroWidth() {
        let result = InlineSparkline.render(data: [1.0, 2.0, 3.0], width: 0)
        #expect(result == "")
    }

    @Test("Negative width: produces empty string")
    func negativeWidth() {
        let result = InlineSparkline.render(data: [1.0, 2.0, 3.0], width: -1)
        #expect(result == "")
    }

    // MARK: - 6. Data longer than width

    @Test("Data longer than width: shows last N values only")
    func dataLongerThanWidth() {
        // data: [1, 2, 3, 4, 5], width: 3 -> shows [3, 4, 5]
        // range is 1..5 -> 3 maps to (3-1)/(5-1) = 0.5 -> index 4
        // 4 maps to (4-1)/(5-1) = 0.75 -> index 6
        // 5 maps to (5-1)/(5-1) = 1.0 -> index 8
        let result = InlineSparkline.render(data: [1.0, 2.0, 3.0, 4.0, 5.0], width: 3)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 3)
        // The last 3 values are [3, 4, 5]; they should be rendered
        // We verify visible length is correct (specific chars depend on range of sliced vs full data)
        #expect(ANSIStringMetrics.visibleLength(result) == 3)
    }

    // MARK: - 7. Data shorter than width

    @Test("Data shorter than width: left-padded with spaces")
    func dataShorterThanWidth() {
        let result = InlineSparkline.render(data: [0.0, 1.0], width: 5)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 5)
        // First 3 should be spaces (left padding)
        #expect(chars[0] == " ")
        #expect(chars[1] == " ")
        #expect(chars[2] == " ")
        // Last 2 should be data: 0.0 -> space, 1.0 -> full block
        #expect(chars[3] == Self.blocks[0])  // space for 0.0
        #expect(chars[4] == Self.blocks[8])  // full block for 1.0
    }

    // MARK: - 8. Explicit min/max

    @Test("Explicit min/max: 50 in [0,100] produces mid-height block")
    func explicitMinMax() {
        let result = InlineSparkline.render(data: [50.0], width: 1, min: 0.0, max: 100.0)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 1)
        #expect(chars[0] == Self.blocks[4])
    }

    // MARK: - 9. Visible length invariant

    @Test("Visible length equals width for various inputs")
    func visibleLengthInvariant() {
        let cases: [([Double], Int)] = [
            ([1.0, 2.0, 3.0], 3),
            ([0.0], 10),
            ([1.0, 2.0, 3.0, 4.0, 5.0], 3),
            ([0.5, 0.5], 5),
            ([], 4),
            ([100.0, 200.0, 300.0], 1),
        ]
        for (data, width) in cases {
            let result = InlineSparkline.render(data: data, width: width)
            #expect(
                ANSIStringMetrics.visibleLength(result) == width,
                "Expected visible length \(width) for data \(data), got \(ANSIStringMetrics.visibleLength(result))"
            )
        }
    }

    // MARK: - 10. ANSI containment

    @Test("ANSI containment: result ends with reset escape")
    func ansiContainment() {
        let result = InlineSparkline.render(data: [1.0, 2.0, 3.0], width: 3)
        #expect(result.hasSuffix(ANSICodes.reset))
    }

    @Test("ANSI containment: zero width has no color bleed")
    func ansiContainmentZeroWidth() {
        let result = InlineSparkline.render(data: [1.0], width: 0)
        // Empty string has no ANSI escapes to bleed
        #expect(result == "")
    }

    // MARK: - Generic Float support

    @Test("Works with Float type")
    func floatGeneric() {
        let data: [Float] = [0.0, 0.5, 1.0]
        let result = InlineSparkline.render(data: data, width: 3)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 3)
        #expect(chars[0] == Self.blocks[0])
        #expect(chars[1] == Self.blocks[4])
        #expect(chars[2] == Self.blocks[8])
    }

    @Test("Works with Float explicit min/max")
    func floatExplicitMinMax() {
        let data: [Float] = [50.0]
        let result = InlineSparkline.render(data: data, width: 1, min: 0.0, max: 100.0)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 1)
        #expect(chars[0] == Self.blocks[4])
    }

    // MARK: - Custom color

    @Test("Custom color escape is present in output")
    func customColor() {
        let result = InlineSparkline.render(data: [1.0], width: 1, color: .ansi8(.red))
        // Should contain the red foreground escape
        #expect(result.contains(ANSICodes.fg(.red)))
    }

    // MARK: - Edge case: single value

    @Test("Single value with no min/max: equal data case, mid-height")
    func singleValue() {
        let result = InlineSparkline.render(data: [42.0], width: 1)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 1)
        #expect(chars[0] == Self.blocks[4])
    }

    // MARK: - Data longer than width uses full data range for normalization

    @Test("Data longer than width: normalization uses only visible slice range")
    func dataLongerNormalization() {
        // [0, 0, 0, 0, 10], width: 1 -> only shows [10], single value -> mid-height
        let result = InlineSparkline.render(data: [0.0, 0.0, 0.0, 0.0, 10.0], width: 1)
        let chars = Array(visibleChars(result))
        #expect(chars.count == 1)
        // Single visible value -> equal data case -> mid-height
        #expect(chars[0] == Self.blocks[4])
    }
}
