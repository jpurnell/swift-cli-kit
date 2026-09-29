// TerminalFormatter.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Width-constrained formatting for terminal display.
///
/// Terminal columns are finite. TerminalFormatter formats numbers and dates
/// to fit within a maximum column width, truncating or abbreviating as needed.
///
/// ```swift
/// TerminalFormatter.formatNumber(1234567.89, locale: "en", maxWidth: 12)
/// // "1,234,567.89"
///
/// TerminalFormatter.formatDate(Date(), locale: "en", maxWidth: 10)
/// // "04/10/2026"
/// ```
public enum TerminalFormatter: Sendable {
    /// Formats a number for terminal display within a maximum column width.
    ///
    /// Uses locale-appropriate grouping and decimal separators.
    /// If the formatted result exceeds `maxWidth`, progressively removes
    /// decimal places, then switches to compact notation (e.g. "1.2M").
    ///
    /// - Parameters:
    ///   - value: The number to format.
    ///   - locale: A locale identifier for formatting rules.
    ///   - maxWidth: The maximum character width allowed.
    /// - Returns: A formatted string that fits within maxWidth.
    public static func formatNumber(
        _ value: Double, locale: String, maxWidth: Int
    ) -> String {
        guard maxWidth > 0 else { return "" }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        // Try full format first
        if let full = formatter.string(from: NSNumber(value: value)),
           full.count <= maxWidth {
            return full
        }

        // Try with fewer decimals
        formatter.maximumFractionDigits = 1
        if let reduced = formatter.string(from: NSNumber(value: value)),
           reduced.count <= maxWidth {
            return reduced
        }

        formatter.maximumFractionDigits = 0
        if let integer = formatter.string(from: NSNumber(value: value)),
           integer.count <= maxWidth {
            return integer
        }

        // Switch to compact notation
        let compactResult = compactFormat(value, maxWidth: maxWidth)
        if compactResult.count <= maxWidth {
            return compactResult
        }

        // Last resort: truncate
        return String(compactResult.prefix(maxWidth))
    }

    /// Formats a date for terminal display within a maximum column width.
    ///
    /// Progressively shortens the format: medium, short, then year-only,
    /// to fit within the given width.
    ///
    /// - Parameters:
    ///   - date: The date to format.
    ///   - locale: A locale identifier for formatting rules.
    ///   - maxWidth: The maximum character width allowed.
    /// - Returns: A formatted string that fits within maxWidth.
    public static func formatDate(
        _ date: Date, locale: String, maxWidth: Int
    ) -> String {
        guard maxWidth > 0 else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: locale)

        // Try medium style first
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let medium = dateFormatter.string(from: date)
        if medium.count <= maxWidth {
            return medium
        }

        // Try short style
        dateFormatter.dateStyle = .short
        let short = dateFormatter.string(from: date)
        if short.count <= maxWidth {
            return short
        }

        // Year only
        let calendar = Calendar.current
        let year = "\(calendar.component(.year, from: date))"
        if year.count <= maxWidth {
            return year
        }

        return String(year.prefix(maxWidth))
    }

    // MARK: - Private

    private static func compactFormat(_ value: Double, maxWidth: Int) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        let suffixes: [(threshold: Double, suffix: String, divisor: Double)] = [
            (1_000_000_000_000, "T", 1_000_000_000_000),
            (1_000_000_000, "B", 1_000_000_000),
            (1_000_000, "M", 1_000_000),
            (1_000, "K", 1_000),
        ]

        for (threshold, suffix, divisor) in suffixes {
            guard absValue >= threshold else { continue }
            let scaled = absValue / divisor

            // Try with one decimal
            let withDecimal = "\(sign)\(Int(scaled * 10) / 10).\(Int(scaled * 10) % 10)\(suffix)"
            if withDecimal.count <= maxWidth {
                return withDecimal
            }

            // Try integer only
            let intOnly = "\(sign)\(Int(scaled))\(suffix)"
            if intOnly.count <= maxWidth {
                return intOnly
            }
        }

        return "\(sign)\(Int(absValue))"
    }
}
