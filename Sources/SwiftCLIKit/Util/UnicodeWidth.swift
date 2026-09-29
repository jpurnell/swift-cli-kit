// UnicodeWidth.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Computes the display width of Unicode scalars, characters, and strings
/// using East Asian Width rules and combining-mark detection.
public enum UnicodeWidth: Sendable {

    // MARK: - Width table (sorted by range start for binary search)

    private static let widthTable: [(range: ClosedRange<UInt32>, width: Int)] = [
        // C0 control characters
        (0x0000...0x001F, 0),
        // DEL + C1 control characters
        (0x007F...0x009F, 0),
        // Combining marks (common ranges) — handled via generalCategory below,
        // but we include the zero-width specials explicitly:
        (0x200B...0x200B, 0), // Zero-width space
        (0x200C...0x200C, 0), // Zero-width non-joiner
        (0x200D...0x200D, 0), // Zero-width joiner
        (0x2060...0x2060, 0), // Word joiner
        (0xFEFF...0xFEFF, 0), // BOM / zero-width no-break space

        // East Asian Wide / Fullwidth ranges
        (0x1100...0x115F, 2), // Hangul Jamo
        (0x2E80...0x303E, 2), // CJK Radicals, Kangxi, Ideographic Description, CJK Symbols
        (0x3040...0x4DBF, 2), // Hiragana, Katakana, Bopomofo, Hangul Compat Jamo, Kanbun, CJK Unified ext A
        (0x4E00...0x9FFF, 2), // CJK Unified Ideographs
        (0xA000...0xA4CF, 2), // Yi Syllables + Radicals
        (0xA960...0xA97F, 2), // Hangul Jamo Extended-A
        (0xAC00...0xD7AF, 2), // Hangul Syllables
        (0xF900...0xFAFF, 2), // CJK Compatibility Ideographs
        (0xFE10...0xFE6F, 2), // Vertical Forms, CJK Compatibility Forms, Small Form Variants
        (0xFF01...0xFF60, 2), // Fullwidth ASCII variants, fullwidth punctuation
        (0xFFE0...0xFFE6, 2), // Fullwidth signs (cent, pound, etc.)

        // Halfwidth forms — width 1 (explicit, overrides any broad range)
        (0xFF61...0xFFDC, 1), // Halfwidth Katakana, Hangul
        (0xFFE8...0xFFEE, 1), // Halfwidth symbols

        // Emoji and symbol blocks
        (0x1F000...0x1FAFF, 2), // Mahjong, Dominos, Playing Cards, Emoji
        // CJK Extension B and beyond
        (0x20000...0x2FFFF, 2),
        (0x30000...0x3FFFF, 2),
    ]

    // MARK: - Scalar width

    /// Returns the display-column width of a single Unicode scalar (0, 1, or 2).
    /// - Parameter scalar: The scalar to measure.
    /// - Returns: 0 for control/combining characters, 2 for CJK/fullwidth, 1 otherwise.
    public static func width(of scalar: Unicode.Scalar) -> Int {
        let value = scalar.value

        // Binary search the width table
        var lo = 0
        var hi = widthTable.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let entry = widthTable[mid]
            if value < entry.range.lowerBound {
                guard mid > 0 else { break }
                hi = mid - 1
            } else if value > entry.range.upperBound {
                lo = mid + 1
            } else {
                return entry.width
            }
        }

        // Combining marks via Unicode properties
        let category = scalar.properties.generalCategory
        switch category {
        case .nonspacingMark, .spacingMark, .enclosingMark:
            return 0
        default:
            break
        }

        return 1
    }

    // MARK: - Character width

    /// Returns the display-column width of a `Character` (grapheme cluster),
    /// accounting for emoji presentation selectors and multi-scalar sequences.
    /// - Parameter character: The character to measure.
    /// - Returns: The number of terminal columns the character occupies.
    public static func width(of character: Character) -> Int {
        let scalars = character.unicodeScalars

        guard let first = scalars.first else { return 0 }

        // Single scalar — delegate directly
        if scalars.count == 1 {
            return width(of: first)
        }

        // Multi-scalar grapheme cluster
        // Check for VS16 (emoji presentation selector)
        let hasVS16 = scalars.contains(where: { $0.value == 0xFE0F })
        if hasVS16 {
            return 2
        }

        // Check if first scalar is in an emoji presentation range
        let v = first.value
        let isEmojiPresentation =
            (0x1F000...0x1FAFF).contains(v) ||
            (0x1F1E0...0x1F1FF).contains(v) || // Regional indicators (flags)
            (0x2600...0x27BF).contains(v) ||    // Misc symbols, Dingbats
            (0x2300...0x23FF).contains(v) ||    // Misc technical
            (0xFE00...0xFE0F).contains(v) ||    // Variation selectors
            (0x200D == v)                        // ZWJ itself

        if isEmojiPresentation {
            return 2
        }

        // Default: width of first scalar (combining marks add 0)
        return width(of: first)
    }

    // MARK: - String display width

    /// Returns the total display-column width of a string.
    /// - Parameter s: The string to measure.
    /// - Returns: The sum of each character's display width.
    public static func displayWidth(_ s: String) -> Int {
        var total = 0
        for character in s {
            total += width(of: character)
        }
        return total
    }
}
