// TerminalColors.swift
// SwiftCLIKit

import Foundation

/// What is known about the terminal's default colours, and how sure we are.
///
/// ``resolve(environment:queried:)`` does no I/O. It combines an environment and an
/// already-parsed query result. It does not look at `NO_COLOR`: callers still decide whether
/// to emit colour at all, and resolving never fails.
public struct TerminalColors: Sendable, Equatable {

    /// How the answer was obtained, from most to least reliable.
    public enum Confidence: Sendable, Equatable {
        /// Set by `SWIFTCLIKIT_BACKGROUND`.
        case explicit
        /// Reported by the terminal.
        case queried
        /// Inferred from `COLORFGBG`.
        case hinted
        /// Nothing known; dark assumed.
        case assumed
    }

    /// The colours a terminal reported, already parsed by the caller.
    public struct QueryResult: Sendable, Equatable {
        /// OSC 11 result, if any.
        public let background: TerminalRGB?
        /// OSC 10 result, if any.
        public let foreground: TerminalRGB?

        /// Creates a query result.
        public init(background: TerminalRGB?, foreground: TerminalRGB?) {
            self.background = background
            self.foreground = foreground
        }
    }

    /// The background colour, or `nil` when only dark or light is known.
    public var background: TerminalRGB?
    /// The default foreground colour, if known.
    public var foreground: TerminalRGB?
    /// Whether the background is dark.
    public var isDark: Bool
    /// How `isDark` and `background` were determined.
    public var confidence: Confidence

    /// Creates a value.
    public init(background: TerminalRGB?, foreground: TerminalRGB?, isDark: Bool, confidence: Confidence) {
        self.background = background
        self.foreground = foreground
        self.isDark = isDark
        self.confidence = confidence
    }

    /// Environment variable that overrides the background: `dark`, `light` or `#RRGGBB`.
    public static let backgroundOverrideKey = "SWIFTCLIKIT_BACKGROUND"
    /// Environment variable that overrides the foreground: `#RRGGBB`.
    public static let foregroundOverrideKey = "SWIFTCLIKIT_FOREGROUND"

    /// Resolves the terminal colours in this order: explicit `SWIFTCLIKIT_BACKGROUND`, then the
    /// caller's query result, then `COLORFGBG`, then an assumption of dark.
    ///
    /// The foreground is the explicit `SWIFTCLIKIT_FOREGROUND` if valid, else the query's.
    /// `confidence` describes `isDark` and `background`. Unusable values are ignored.
    ///
    /// - Parameters:
    ///   - environment: Environment variables, typically `ProcessInfo.processInfo.environment`.
    ///   - queried: A parsed OSC 10/11 result, or `nil` if no query was made or it failed.
    public static func resolve(environment: [String: String], queried: QueryResult?) -> TerminalColors {
        let foreground = environment[foregroundOverrideKey].flatMap { TerminalRGB(hex: $0) } ?? queried?.foreground

        if let override = environment[backgroundOverrideKey] {
            switch override.lowercased() {
            case "dark":
                return TerminalColors(background: nil, foreground: foreground, isDark: true, confidence: .explicit)
            case "light":
                return TerminalColors(background: nil, foreground: foreground, isDark: false, confidence: .explicit)
            default:
                if override.hasPrefix("#"), let color = TerminalRGB(hex: override) {
                    return TerminalColors(background: color, foreground: foreground, isDark: isDark(color), confidence: .explicit)
                }
            }
        }

        if let color = queried?.background {
            return TerminalColors(background: color, foreground: foreground, isDark: isDark(color), confidence: .queried)
        }

        if let hint = environment["COLORFGBG"].flatMap({ ColorFGBG.parse($0) }), let dark = hint.isDark {
            return TerminalColors(background: nil, foreground: foreground, isDark: dark, confidence: .hinted)
        }

        return TerminalColors(background: nil, foreground: foreground, isDark: true, confidence: .assumed)
    }

    /// A background is dark when black text would contrast less with it than white text would.
    private static func isDark(_ color: TerminalRGB) -> Bool {
        let black = TerminalRGB(r: 0, g: 0, b: 0)
        let white = TerminalRGB(r: 255, g: 255, b: 255)
        return ColorMath.contrastRatio(color, white) >= ColorMath.contrastRatio(color, black)
    }
}
