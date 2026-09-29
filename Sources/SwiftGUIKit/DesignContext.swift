// DesignContext.swift
// SwiftGUIKit
//
// The adaptivity axis — one cross-surface generalization of SwiftUI's
// Environment / trait collection. Resolvers read it; components mostly don't.

import SwiftCLIKit

/// The capability and appearance context a `TokenResolver` resolves against.
public struct DesignContext: Sendable, Equatable {

    /// The active appearance mode.
    public enum Appearance: Sendable, Hashable {
        case light           // LIVE: public appearance vocabulary
        case dark
        case highContrast
        case system          // LIVE: public appearance vocabulary
    }

    /// Layout density; the terminal is inherently ultra-compact.
    public enum Density: Sendable, Hashable { case compact, regular, spacious }

    /// The pointing capability. `none` means keyboard-first (terminal), which
    /// forces focus to be *visible* rather than relying on hover.
    public enum Pointer: Sendable, Hashable { case none, mouse, touch }

    /// The glyph fidelity available for symbols.
    public enum GlyphCapability: Int, Sendable, Hashable, Comparable {
        /// ASCII only (limited fonts).
        case ascii
        /// Unicode / nerd-font glyphs.
        case unicode
        /// Native symbol rendering (e.g. SF Symbols).
        case native          // LIVE: public glyph-capability vocabulary

        /// Orders capabilities from least (`ascii`) to most (`native`) capable.
        public static func < (lhs: GlyphCapability, rhs: GlyphCapability) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The rendering surface a resolver is targeting.
    public enum SurfaceKind: Sendable, Hashable {
        case terminal
        case ssh             // LIVE: public surface vocabulary
        case swiftUI
        case appKit          // LIVE: public surface vocabulary
        case dom             // LIVE: public surface vocabulary
    }

    /// The active appearance mode.
    public var appearance: Appearance
    /// The layout density.
    public var density: Density
    /// The color fidelity of the surface (reuses SwiftCLIKit's negotiation type).
    public var colorDepth: ColorCapability
    /// The glyph fidelity of the surface.
    public var glyphCapability: GlyphCapability
    /// The pointing capability.
    public var pointer: Pointer
    /// Whether hover is available (false on terminal and touch).
    public var hasHover: Bool
    /// Whether the user prefers reduced motion.
    public var reduceMotion: Bool
    /// The rendering surface.
    public var surface: SurfaceKind

    /// Creates a design context.
    public init(
        appearance: Appearance = .dark,
        density: Density = .compact,
        colorDepth: ColorCapability = .truecolor,
        glyphCapability: GlyphCapability = .unicode,
        pointer: Pointer = .none,
        hasHover: Bool = false,
        reduceMotion: Bool = false,
        surface: SurfaceKind = .terminal
    ) {
        self.appearance = appearance
        self.density = density
        self.colorDepth = colorDepth
        self.glyphCapability = glyphCapability
        self.pointer = pointer
        self.hasHover = hasHover
        self.reduceMotion = reduceMotion
        self.surface = surface
    }

    /// Whether this context is a color-less "mono floor" — status must not be
    /// conveyed by color alone here.
    public var isMonoFloor: Bool { colorDepth == .none }

    // MARK: Terminal presets

    /// A truecolor terminal with unicode glyphs.
    public static let terminalTruecolor = DesignContext(
        colorDepth: .truecolor, glyphCapability: .unicode)

    /// A colorless, ASCII-only terminal — the poorest faithful floor.
    public static let terminalMono = DesignContext(
        colorDepth: .none, glyphCapability: .ascii)
}
