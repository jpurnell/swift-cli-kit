// ANSIStringMetrics.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Utilities for measuring and manipulating strings that contain ANSI escape sequences.
public enum ANSIStringMetrics: Sendable {

    // MARK: - ANSI escape stripping

    /// Strips ANSI escape sequences from a string.
    private static func stripANSI(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[[0-9;]*[A-Za-z]") else { // silent: regex is compile-time constant
            return s
        }
        let range = NSRange(s.startIndex..., in: s)
        return regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    }

    /// Returns the string with ANSI escape sequences removed, leaving only visible text.
    ///
    /// Useful for extracting copy-ready text from rendered terminal output.
    /// - Parameter s: A string possibly containing ANSI escape sequences.
    /// - Returns: The string with all CSI escape sequences stripped.
    public static func plainText(_ s: String) -> String {
        stripANSI(s)
    }

    // MARK: - Visible length

    /// Returns the visible (non-escape) display width of a string, using ``UnicodeWidth``.
    /// - Parameter s: A string possibly containing ANSI escape sequences.
    /// - Returns: The column width after stripping escapes.
    public static func visibleLength(_ s: String) -> Int {
        let stripped = stripANSI(s)
        return UnicodeWidth.displayWidth(stripped)
    }

    // MARK: - Pad to visible width

    /// Right-pads a string with spaces so its visible width reaches the target.
    /// - Parameter s: The input string (may contain ANSI escapes).
    /// - Parameter width: The desired visible width.
    /// - Returns: The padded string, unchanged if already at or beyond the target width.
    public static func padVisible(_ s: String, to width: Int) -> String {
        let visible = visibleLength(s)
        guard visible < width else { return s }
        return s + String(repeating: " ", count: width - visible)
    }

    // MARK: - Truncate to visible width

    /// Truncates a string to fit within a visible column budget, preserving ANSI escapes
    /// and appending a reset sequence if any escape was left open.
    /// - Parameter s: The input string (may contain ANSI escapes).
    /// - Parameter maxWidth: The maximum visible column width.
    /// - Returns: The truncated string with ANSI state properly closed.
    public static func truncateVisible(_ s: String, to maxWidth: Int) -> String {
        guard maxWidth >= 0 else { return "" }

        var result = ""
        var currentWidth = 0
        var inEscape = false
        var hasOpenANSI = false

        let characters = Array(s)
        var i = 0

        while i < characters.count {
            let ch = characters[i]

            // Check for ESC starting an ANSI sequence
            if ch == "\u{001B}" {
                // Look ahead for '['
                if i + 1 < characters.count, characters[i + 1] == "[" {
                    inEscape = true
                    hasOpenANSI = true
                    result.append(ch)
                    i += 1
                    continue
                }
            }

            if inEscape {
                result.append(ch)
                // ANSI escape ends at a letter A-Z or a-z
                let scalar = ch.unicodeScalars.first
                if let s = scalar {
                    let v = s.value
                    if (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) {
                        inEscape = false
                        // Check if this was a reset sequence
                        if result.hasSuffix("\u{001B}[0m") {
                            hasOpenANSI = false
                        }
                    }
                }
                i += 1
                continue
            }

            let charWidth = UnicodeWidth.width(of: ch)

            // Would this character exceed the budget?
            if currentWidth + charWidth > maxWidth {
                // Wide char doesn't fit — pad with spaces for remaining columns
                let remaining = maxWidth - currentWidth
                if remaining > 0 {
                    result += String(repeating: " ", count: remaining)
                }
                break
            }

            result.append(ch)
            currentWidth += charWidth
            i += 1
        }

        // If we opened ANSI escapes and haven't reset, append reset
        if hasOpenANSI {
            result += ANSICodes.reset
        }

        return result
    }

    // MARK: - Middle elision

    /// Elides a string from the middle so both the leading text and the trailing
    /// suffix survive, joined by a horizontal ellipsis (`…`).
    ///
    /// Unlike ``truncateVisible(_:to:)``, which clips from the right, this keeps the
    /// distinguishing tail of an identifier. It deliberately favors preserving a
    /// whole trailing camel-case suffix (for example `Kit`, `UI`, `BASIC`) over an
    /// even left/right split, so sibling module names stay distinguishable at a
    /// glance: `HarborKit` → `Ha…Kit`, `HarborUI` → `Har…UI`.
    ///
    /// The string is returned unchanged when it already fits, so callers can use
    /// `elideMiddle(s, to: w) != s` as a "was this elided?" signal — for example to
    /// decide whether a hover tooltip is warranted.
    ///
    /// Interior ANSI escape sequences are stripped; the result is plain visible
    /// text. Apply any styling to the returned value.
    ///
    /// - Parameters:
    ///   - s: The input string (ANSI escapes, if present, are removed).
    ///   - maxWidth: The maximum visible column width of the result.
    /// - Returns: The middle-elided string, never wider than `maxWidth` columns.
    public static func elideMiddle(_ s: String, to maxWidth: Int) -> String {
        guard maxWidth > 0 else { return "" }
        let plain = stripANSI(s)
        guard UnicodeWidth.displayWidth(plain) > maxWidth else { return plain }

        let ellipsis = "…"
        guard maxWidth > 1 else { return ellipsis }

        let characters = Array(plain)
        let budget = maxWidth - 1 // reserve one column for the ellipsis

        // Favor keeping the whole trailing camel-case suffix, but always leave the
        // head at least one column.
        let suffix = trailingCamelSuffix(characters)
        let suffixWidth = UnicodeWidth.displayWidth(String(suffix))
        let rightBudget = min(suffixWidth, budget - 1)
        let leftBudget = budget - rightBudget

        // Accumulate the head from the front without splitting a wide grapheme.
        var head = ""
        var headWidth = 0
        for ch in characters {
            let w = UnicodeWidth.width(of: ch)
            if headWidth + w > leftBudget { break }
            head.append(ch)
            headWidth += w
        }

        // Accumulate the tail from the back without splitting a wide grapheme.
        var tail: [Character] = []
        var tailWidth = 0
        for ch in characters.reversed() {
            let w = UnicodeWidth.width(of: ch)
            if tailWidth + w > rightBudget { break }
            tail.append(ch)
            tailWidth += w
        }

        return head + ellipsis + String(tail.reversed())
    }

    /// Returns the trailing camel-case word of an identifier: a capitalized word
    /// (`…Kit`), an acronym run (`…UI`, `…BASIC`), or the trailing run of letters
    /// when the string is a single lowercase token.
    private static func trailingCamelSuffix(_ characters: [Character]) -> ArraySlice<Character> {
        guard let last = characters.indices.last else { return characters[...] }

        func isLowerPart(_ c: Character) -> Bool { c.isNumber || (c.isLetter && c.isLowercase) }
        func isUpper(_ c: Character) -> Bool { c.isLetter && c.isUppercase }

        var start = last
        if isLowerPart(characters[last]) {
            // Walk back over the trailing lowercase run, then absorb the
            // capital that starts the camel-case word (if any).
            while start > 0 && isLowerPart(characters[start - 1]) { start -= 1 }
            if start > 0 && isUpper(characters[start - 1]) { start -= 1 }
        } else if isUpper(characters[last]) {
            // Trailing acronym: keep the whole uppercase run.
            while start > 0 && isUpper(characters[start - 1]) { start -= 1 }
        }
        return characters[start...last]
    }
}
