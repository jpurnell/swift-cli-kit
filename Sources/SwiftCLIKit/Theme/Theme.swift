// Theme.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A named collection of semantic colors for consistent UI styling.
///
/// Themes map abstract roles (primary, error, muted, etc.) to concrete ``Color``
/// values, making it easy to restyle an entire application by swapping themes.
///
/// ```swift
/// let style = Theme.dark.style(fg: \.error, bg: \.surface, attributes: .bold)
/// ```
public struct Theme: Sendable, Codable, Equatable {
    /// The display name of this theme.
    public var name: String
    /// The primary accent color.
    public var primary: Color
    /// The secondary accent color.
    public var secondary: Color
    /// The color for error messages and indicators.
    public var error: Color
    /// The color for warning messages.
    public var warning: Color
    /// The color for success messages.
    public var success: Color
    /// A muted/dimmed color for less important text.
    public var muted: Color
    /// The surface background color (cards, panels).
    public var surface: Color
    /// The text color on surfaces.
    public var onSurface: Color
    /// The main background color.
    public var background: Color
    /// The text color on the main background.
    public var onBackground: Color
    /// The color for borders and dividers.
    public var border: Color
    /// The background color for highlighted/selected items.
    public var highlight: Color
    /// The text color on highlighted items.
    public var highlightText: Color

    /// A dark theme preset.
    public static let dark = Theme(
        name: "dark",
        primary: .truecolor(r: 97, g: 175, b: 239),
        secondary: .truecolor(r: 152, g: 195, b: 121),
        error: .truecolor(r: 224, g: 108, b: 117),
        warning: .truecolor(r: 229, g: 192, b: 123),
        success: .truecolor(r: 152, g: 195, b: 121),
        muted: .truecolor(r: 92, g: 99, b: 112),
        surface: .truecolor(r: 40, g: 44, b: 52),
        onSurface: .truecolor(r: 171, g: 178, b: 191),
        background: .truecolor(r: 30, g: 33, b: 39),
        onBackground: .truecolor(r: 171, g: 178, b: 191),
        border: .truecolor(r: 62, g: 68, b: 81),
        highlight: .truecolor(r: 97, g: 175, b: 239),
        highlightText: .truecolor(r: 30, g: 33, b: 39)
    )

    /// A light theme preset.
    public static let light = Theme(
        name: "light",
        primary: .truecolor(r: 0, g: 122, b: 204),
        secondary: .truecolor(r: 56, g: 132, b: 60),
        error: .truecolor(r: 205, g: 49, b: 49),
        warning: .truecolor(r: 191, g: 134, b: 16),
        success: .truecolor(r: 56, g: 132, b: 60),
        muted: .truecolor(r: 150, g: 150, b: 150),
        surface: .truecolor(r: 255, g: 255, b: 255),
        onSurface: .truecolor(r: 51, g: 51, b: 51),
        background: .truecolor(r: 245, g: 245, b: 245),
        onBackground: .truecolor(r: 51, g: 51, b: 51),
        border: .truecolor(r: 200, g: 200, b: 200),
        highlight: .truecolor(r: 0, g: 122, b: 204),
        highlightText: .truecolor(r: 255, g: 255, b: 255)
    )

    /// Creates a ``CellStyle`` from theme color roles.
    /// - Parameters:
    ///   - role: A key path to the foreground color role.
    ///   - bgRole: A key path to the background color role (default: `\.background`).
    ///   - attributes: Text attributes to apply.
    /// - Returns: A ``CellStyle`` configured from the theme.
    public func style(
        fg role: KeyPath<Theme, Color>,
        bg bgRole: KeyPath<Theme, Color> = \.background,
        attributes: CellAttributes = []
    ) -> CellStyle {
        CellStyle(fg: self[keyPath: role], bg: self[keyPath: bgRole], attributes: attributes)
    }
}
