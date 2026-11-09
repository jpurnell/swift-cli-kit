// ColorFGBG.swift
// SwiftCLIKit

import Foundation

/// The parsed value of the `COLORFGBG` environment variable some terminals set.
///
/// The variable holds ANSI palette indices (`fg;bg`, or `fg;default;bg`), not colours, so it
/// supports only a dark or light guess.
public struct ColorFGBG: Sendable, Equatable {
    /// Foreground palette index, or `nil` when the field was `default`.
    public let foreground: Int?
    /// Background palette index, or `nil` when the field was `default`.
    public let background: Int?
    /// `true` for background indices 0 to 6 and 8, `false` for 7 and 15, `nil` when unknown.
    public let isDark: Bool?

    /// Creates a value.
    public init(foreground: Int?, background: Int?, isDark: Bool?) {
        self.foreground = foreground
        self.background = background
        self.isDark = isDark
    }

    /// Parses a `COLORFGBG` value.
    /// - Parameter value: For example `"15;0"` or `"0;default;15"`.
    /// - Returns: `nil` if the value is not two or three `;`-separated fields of a 0 to 255
    ///   index or `default`. A well-formed value that says nothing yields a value with `nil` fields.
    public static func parse(_ value: String) -> ColorFGBG? {
        let fields = value.split(separator: ";", omittingEmptySubsequences: false)
        guard fields.count == 2 || fields.count == 3 else { return nil }
        guard let first = fields.first, let last = fields.last else { return nil }
        guard let foreground = parseField(first), let background = parseField(last) else { return nil }
        if fields.count == 3 {
            guard parseField(fields[1]) != nil else { return nil }
        }
        return ColorFGBG(
            foreground: foreground.value,
            background: background.value,
            isDark: darkness(of: background.value)
        )
    }

    private struct Field {
        let value: Int?
    }

    private static func parseField(_ text: Substring) -> Field? {
        if text == "default" { return Field(value: nil) }
        guard !text.isEmpty, text.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
        guard let number = Int(text), number <= 255 else { return nil }
        return Field(value: number)
    }

    private static func darkness(of index: Int?) -> Bool? {
        guard let index else { return nil }
        switch index {
        case 0...6, 8: return true
        case 7, 15: return false
        default: return nil
        }
    }
}
