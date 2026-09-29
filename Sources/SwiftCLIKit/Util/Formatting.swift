// Formatting.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-05-07.

import Foundation

/// Human-readable formatting utilities for durations, byte counts, timestamps, and rates.
///
/// All methods are pure functions with no side effects. Negative or invalid inputs
/// are clamped to sensible defaults rather than trapping.
///
/// ```swift
/// Formatting.elapsed(90)           // "1m 30s"
/// Formatting.duration(3723)        // "1h 2m 3s"
/// Formatting.bytes(1_048_576)      // "1.0 MB"
/// Formatting.rate(1.5, unit: "games/min")  // "1.5 games/min"
/// ```
public enum Formatting: Sendable {

    // MARK: - Elapsed (compact, drops seconds for > 1h)

    /// Formats a number of seconds into a compact elapsed string.
    ///
    /// - Under 60 s: `"< 1m"`
    /// - 60 s to < 3600 s: `"Xm Ys"`
    /// - 3600 s and above: `"Xh Ym"` (seconds dropped)
    ///
    /// Negative and zero values return `"< 1m"`.
    ///
    /// - Parameter seconds: The elapsed time in seconds.
    /// - Returns: A human-readable duration string.
    public static func elapsed(_ seconds: Double) -> String {
        guard seconds >= 60 else { return "< 1m" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m \(s)s"
    }

    // MARK: - Duration (full precision)

    /// Formats a `TimeInterval` into a full-precision duration string.
    ///
    /// - Under 1 s: `"< 1s"`
    /// - 1 s to < 60 s: `"Xs"`
    /// - 60 s to < 3600 s: `"Xm Ys"`
    /// - 3600 s and above: `"Xh Ym Zs"`
    ///
    /// Negative values return `"< 1s"`.
    ///
    /// - Parameter interval: The duration in seconds.
    /// - Returns: A human-readable duration string.
    public static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        guard totalSeconds >= 1 else { return "< 1s" }
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return "\(h)h \(m)m \(s)s"
        }
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return "\(s)s"
    }

    // MARK: - Bytes

    private enum ByteUnit {
        static let kilo: Int64 = 1_024
        static let mega: Int64 = 1_048_576
        static let giga: Int64 = 1_073_741_824
    }

    /// Formats a byte count into a human-readable string with an appropriate unit.
    ///
    /// Uses binary units (1 KB = 1024 bytes). Values in KB, MB, and GB are shown
    /// with one decimal place.
    ///
    /// - Under 1 KB: `"X B"`
    /// - 1 KB to < 1 MB: `"X.X KB"`
    /// - 1 MB to < 1 GB: `"X.X MB"`
    /// - 1 GB and above: `"X.X GB"`
    ///
    /// Negative values return `"0 B"`.
    ///
    /// - Parameter count: The byte count.
    /// - Returns: A human-readable byte string.
    public static func bytes(_ count: Int64) -> String {
        guard count > 0 else { return "0 B" }
        let dCount = Double(count)
        if count >= ByteUnit.giga {
            let divisor = Double(ByteUnit.giga)
            guard divisor > 0 else { return "0 B" }
            return formatOneDecimal(dCount / divisor) + " GB"
        }
        if count >= ByteUnit.mega {
            let divisor = Double(ByteUnit.mega)
            guard divisor > 0 else { return "0 B" }
            return formatOneDecimal(dCount / divisor) + " MB"
        }
        if count >= ByteUnit.kilo {
            let divisor = Double(ByteUnit.kilo)
            guard divisor > 0 else { return "0 B" }
            return formatOneDecimal(dCount / divisor) + " KB"
        }
        return "\(count) B"
    }

    // MARK: - Time

    /// Formats a `Date` as `HH:mm:ss` in the given time zone.
    ///
    /// - Parameters:
    ///   - date: The date to format.
    ///   - timeZone: The time zone to use for formatting. Defaults to the current system timezone.
    /// - Returns: A 24-hour time string like `"14:30:00"`.
    public static func time(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// Formats a `Date` as `HH:mm` in the given time zone.
    ///
    /// - Parameters:
    ///   - date: The date to format.
    ///   - timeZone: The time zone to use for formatting. Defaults to the current system timezone.
    /// - Returns: A short 24-hour time string like `"14:30"`.
    public static func timeShort(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    // MARK: - Rate

    /// Formats a rate value with one decimal place and a unit suffix.
    ///
    /// Negative values are clamped to `0.0`.
    ///
    /// - Parameters:
    ///   - value: The rate value.
    ///   - unit: The unit string (e.g. `"games/min"`, `"req/s"`).
    /// - Returns: A formatted rate string like `"1.5 games/min"`.
    public static func rate(_ value: Double, unit: String) -> String {
        let clamped = Swift.max(value, 0.0)
        return formatOneDecimal(clamped) + " " + unit
    }

    // MARK: - Private

    /// Formats a Double to exactly one decimal place without locale sensitivity.
    private static func formatOneDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let intPart = Int(rounded)
        let fracPart = Int(((rounded - Double(intPart)) * 10).rounded())
        return "\(intPart).\(fracPart)"
    }
}
