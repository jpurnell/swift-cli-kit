// Tokens.swift
// SwiftGUIKit
//
// The v1 semantic design-token vocabulary. Components name these roles; they
// never name literal colors, point sizes, glyphs, or durations. Each surface
// ships a `TokenResolver` that turns a role into concrete styling — deferring to
// Apple's HIG on native, and faithfully synthesizing it on the terminal floor.
//
// See development-guidelines/02_IMPLEMENTATION_PLANS/PROPOSALS/
//   2026-07-10_TokenVocabulary_v1.md

/// Semantic foreground/background color roles (9). Resolved per surface.
public enum ColorRole: Sendable, Hashable, CaseIterable {
    /// Primary content color.
    case label
    /// De-emphasized content color.
    case secondaryLabel
    /// The primary surface behind content.
    case background
    /// A secondary surface for panels and cards.
    case secondaryBackground
    /// Hairlines, borders, and box-drawing.
    case separator
    /// The application tint.
    case accent
    /// Destructive / error status.
    case destructive
    /// Success status.
    case success
    /// Warning status.
    case warning
}

/// Semantic type roles (5). On the terminal these are carried by weight, dim,
/// case, and rules — not point size.
public enum TypeRole: Sendable, Hashable, CaseIterable {
    /// Screen or section title.
    case title
    /// Group or row heading.
    case heading
    /// Default running text.
    case body
    /// Secondary / metadata text.
    case caption
    /// Code or tabular (monospaced) text.
    case mono
}

/// Abstract spacing steps (t-shirt scale). The resolver quantizes to the
/// surface: cells on the terminal, points on Apple, rem in the DOM.
public enum SpaceToken: Sendable, Hashable, CaseIterable {
    case xs, s, m, l, xl
}

/// Depth levels for containers and overlays (3).
public enum Elevation: Sendable, Hashable, CaseIterable {
    /// No border or shadow.
    case flat
    /// A bordered / grouped container.
    case raised
    /// A floating overlay (material + shadow on native; border + shadow chars on terminal).
    case overlay
}

/// Motion intent (3). `DesignContext.reduceMotion` collapses all roles to `none`.
public enum MotionRole: Sendable, Hashable, CaseIterable {
    case none, standard, emphasized
}

/// Semantic interaction state a widget declares (hover/pressed are handled by
/// native controls and absent on the terminal, so they are not modeled here).
public enum WidgetState: Sendable, Hashable, CaseIterable {
    case normal, focused, selected, disabled
}

/// The axis a spacing metric applies to. The terminal resolver halves vertical
/// spacing to compensate for the ~2:1 cell aspect ratio.
public enum Axis: Sendable, Hashable {
    case horizontal, vertical
}
