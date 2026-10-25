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

        let formatLocale = Locale(identifier: locale)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = formatLocale

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

        // Year only, in the requested locale's calendar and the formatter's time zone
        // so it names the same year the medium and short styles above would.
        var calendar = formatLocale.calendar
        calendar.timeZone = dateFormatter.timeZone
        let year = "\(calendar.component(.year, from: date))"
        if year.count <= maxWidth {
            return year
        }

        return String(year.prefix(maxWidth))
    }

    // MARK: - Private

    /// Compact notation (`1.2M`, `98K`) for a value too wide to print in full.
    ///
    /// Works on the whole part of the magnitude in integer arithmetic, so the
    /// digits are exact. A value whose magnitude an `Int` cannot hold — NaN, an
    /// infinity, or anything from 9e18 up — has no compact form, and is returned
    /// as Swift writes it (`nan`, `-inf`, `1e+300`) for the caller to truncate.
    ///
    /// - Parameters:
    ///   - value: The value to format.
    ///   - maxWidth: The width the result should fit.
    /// - Returns: The compact form, or Swift's own description of a value with none.
    private static func compactFormat(_ value: Double, maxWidth: Int) -> String {
        let absValue = abs(value)
        guard absValue >= 0, absValue < 9e18 else { return "\(value)" }
        let whole = Int(absValue)
        let sign = value < 0 ? "-" : ""

        let suffixes: [(suffix: String, divisor: Int)] = [
            ("T", 1_000_000_000_000),
            ("B", 1_000_000_000),
            ("M", 1_000_000),
            ("K", 1_000),
        ]

        for (suffix, divisor) in suffixes {
            guard whole >= divisor else { continue }
            let tenths = whole / (divisor / 10)

            // Try with one decimal
            let withDecimal = "\(sign)\(tenths / 10).\(tenths % 10)\(suffix)"
            if withDecimal.count <= maxWidth {
                return withDecimal
            }

            // Try integer only
            let intOnly = "\(sign)\(whole / divisor)\(suffix)"
            if intOnly.count <= maxWidth {
                return intOnly
            }
        }

        return "\(sign)\(whole)"
    }
}
