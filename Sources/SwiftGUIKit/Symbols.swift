// Symbols.swift
// SwiftGUIKit
//
// Symbols use a closed semantic enum (`Symbol`) that the widget catalog
// references, plus a pluggable `SymbolSet` that maps each symbol to per-surface
// glyphs. Widgets always speak `Symbol`, never a glyph — so iconography can be
// swapped per `Program` without touching a widget.

/// Closed set of semantic symbols the widget catalog references. A symbol enters
/// this enum only if a widget uses it and it has a faithful terminal glyph.
public enum Symbol: Sendable, Hashable, CaseIterable {
    /// A collapsed disclosure indicator (`Tree`, `Dropdown`).
    case disclosureCollapsed
    /// An expanded disclosure indicator (`Tree`).
    case disclosureExpanded
    /// A checkmark (`Checkbox`, `Form`).
    case check
    /// A selected radio option (`RadioGroup`).
    case radioOn
    /// An unselected radio option (`RadioGroup`).
    case radioOff
    /// A close / dismiss affordance (`Tabs`, `Toast`).
    case close
    /// A warning indicator (`Toast`, status).
    case warning
    /// An informational indicator (`Toast`).
    case info
    /// A search affordance (`CommandPalette`).
    case search
    /// An overflow / more affordance (`Menu`).
    case overflow
    /// An ascending sort / upward trend indicator (`Table`, `Sparkline`).
    case sortAscending
    /// A descending sort / downward trend indicator (`Table`, `Sparkline`).
    case sortDescending
}

/// All per-surface representations of one symbol. A `TokenResolver` selects the
/// field appropriate to the surface and font capability in a `DesignContext`.
public struct GlyphMapping: Sendable, Hashable {
    /// The SF Symbol name used on Apple platforms.
    public let sf: String
    /// A unicode / nerd-font glyph for capable terminals.
    public let unicode: String
    /// An ASCII fallback for limited fonts.
    public let ascii: String

    /// Creates a glyph mapping.
    /// - Parameters:
    ///   - sf: SF Symbol name (Apple).
    ///   - unicode: Unicode / nerd-font glyph.
    ///   - ascii: ASCII floor.
    public init(sf: String, unicode: String, ascii: String) {
        self.sf = sf
        self.unicode = unicode
        self.ascii = ascii
    }
}

/// A pluggable mapping from semantic `Symbol` to `GlyphMapping`. Total by
/// construction — a conforming set must answer for every `Symbol`.
public protocol SymbolSet: Sendable {
    /// Returns the glyph mapping for the given semantic symbol.
    func mapping(for symbol: Symbol) -> GlyphMapping
}

/// The HIG-baseline default symbol set (the 12 v1 mappings). Used unless a
/// consumer supplies another set.
public struct DefaultSymbolSet: SymbolSet {
    /// Creates the default symbol set.
    public init() {}

    /// Returns the baseline glyph mapping for the given symbol.
    public func mapping(for symbol: Symbol) -> GlyphMapping {
        switch symbol {
        case .disclosureCollapsed: GlyphMapping(sf: "chevron.right", unicode: "▸", ascii: ">")
        case .disclosureExpanded:  GlyphMapping(sf: "chevron.down", unicode: "▾", ascii: "v")
        case .check:               GlyphMapping(sf: "checkmark", unicode: "✓", ascii: "x")
        case .radioOn:             GlyphMapping(sf: "circle.inset.filled", unicode: "●", ascii: "*")
        case .radioOff:            GlyphMapping(sf: "circle", unicode: "○", ascii: "o")
        case .close:               GlyphMapping(sf: "xmark", unicode: "✕", ascii: "x")
        case .warning:             GlyphMapping(sf: "exclamationmark.triangle", unicode: "⚠", ascii: "!")
        case .info:                GlyphMapping(sf: "info.circle", unicode: "ⓘ", ascii: "i")
        case .search:              GlyphMapping(sf: "magnifyingglass", unicode: "⌕", ascii: "/")
        case .overflow:            GlyphMapping(sf: "ellipsis", unicode: "…", ascii: "...")
        case .sortAscending:       GlyphMapping(sf: "arrow.up", unicode: "▲", ascii: "^")
        case .sortDescending:      GlyphMapping(sf: "arrow.down", unicode: "▼", ascii: "v")
        }
    }
}

/// A convenience set that keeps a base set but overrides selected symbols.
public struct OverlaySymbolSet: SymbolSet {
    private let base: any SymbolSet
    private let overrides: [Symbol: GlyphMapping]

    /// Creates an overlay over `base`, substituting `overrides` where present.
    /// - Parameters:
    ///   - base: The set consulted for any symbol not in `overrides`.
    ///   - overrides: Per-symbol replacements layered on top of `base`.
    public init(base: any SymbolSet, overrides: [Symbol: GlyphMapping]) {
        self.base = base
        self.overrides = overrides
    }

    /// Returns the override for `symbol` if present, otherwise the base mapping.
    public func mapping(for symbol: Symbol) -> GlyphMapping {
        overrides[symbol] ?? base.mapping(for: symbol)
    }
}
