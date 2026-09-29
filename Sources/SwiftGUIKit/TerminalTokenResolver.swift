// TerminalTokenResolver.swift
// SwiftGUIKit
//
// The terminal `TokenResolver` — the `Theme` evolution. It synthesizes the HIG
// semantics of each token onto a terminal cell grid, honoring three floor rules:
//   1. mono-floor  — status is never color-only; it carries a symbol prefix.
//   2. vertical halving — spacing is halved on the vertical axis (2:1 cell aspect).
//   3. glyph-by-capability — unicode vs ASCII chosen from `DesignContext`.

import SwiftCLIKit

/// A `TokenResolver` that renders tokens to a terminal, driven by a `Theme` and
/// a pluggable `SymbolSet`.
public struct TerminalTokenResolver: TokenResolver {

    /// The palette this resolver draws concrete colors from.
    public let theme: Theme
    /// The active symbol set.
    public let symbols: any SymbolSet

    /// Creates a terminal resolver.
    /// - Parameters:
    ///   - theme: The palette (default: `.dark`).
    ///   - symbols: The symbol set (default: `DefaultSymbolSet()`).
    public init(theme: Theme = .dark, symbols: any SymbolSet = DefaultSymbolSet()) {
        self.theme = theme
        self.symbols = symbols
    }

    // MARK: Color

    /// Resolves a color role to a terminal color, dimming/bolding and adding a
    /// mono-floor prefix as the context requires.
    public func color(_ role: ColorRole, in ctx: DesignContext) -> ResolvedColor {
        let mono = ctx.isMonoFloor
        // High contrast: `.dim` lowers contrast, so drop it — de-emphasis then
        // reads through hue alone, keeping every glyph at full strength.
        let deemphasis: CellAttributes = ctx.appearance == .highContrast ? [] : .dim
        switch role {
        case .label:
            return ResolvedColor(color: .default)
        case .secondaryLabel:
            // De-emphasis reads on every surface via dim; color adds nuance.
            return ResolvedColor(color: mono ? .default : theme.muted, attributes: deemphasis)
        case .background:
            return ResolvedColor(color: mono ? .default : theme.background)
        case .secondaryBackground:
            return ResolvedColor(color: mono ? .default : theme.surface)
        case .separator:
            return ResolvedColor(color: mono ? .default : theme.border, attributes: deemphasis)
        case .accent:
            return mono
                ? ResolvedColor(color: .default, attributes: .bold)
                : ResolvedColor(color: theme.primary)
        case .destructive:
            return statusColor(theme.error, prefix: "!", mono: mono, ctx: ctx)
        case .success:
            return statusColor(theme.success, prefix: successPrefix(ctx), mono: mono, ctx: ctx)
        case .warning:
            return statusColor(theme.warning, prefix: warningPrefix(ctx), mono: mono, ctx: ctx)
        }
    }

    /// Status colors keep their hue when color is available; on the mono floor
    /// they drop to bold + a symbol prefix so meaning survives.
    private func statusColor(_ color: Color, prefix: String, mono: Bool, ctx: DesignContext) -> ResolvedColor {
        mono
            ? ResolvedColor(color: .default, attributes: .bold, monoPrefix: prefix)
            : ResolvedColor(color: color)
    }

    private func successPrefix(_ ctx: DesignContext) -> String {
        ctx.glyphCapability >= .unicode ? "✓" : "+"
    }

    private func warningPrefix(_ ctx: DesignContext) -> String {
        ctx.glyphCapability >= .unicode ? "⚠" : "*"
    }

    // MARK: Type

    /// Resolves a type role to terminal weight/dim (the terminal has one size).
    public func font(_ role: TypeRole, in ctx: DesignContext) -> ResolvedFont {
        switch role {
        case .title:   return ResolvedFont(attributes: .bold)
        case .heading: return ResolvedFont(attributes: .bold)
        case .body:    return ResolvedFont()
        case .caption: return ResolvedFont(attributes: .dim)
        case .mono:    return ResolvedFont() // the terminal is already monospaced
        }
    }

    // MARK: Spacing

    /// Resolves a spacing token to terminal cells, halving the vertical axis.
    /// Density adds breathing room above the inherently compact terminal floor:
    /// `regular` adds one cell, `spacious` two (to non-zero spacing only).
    public func space(_ token: SpaceToken, axis: Axis, in ctx: DesignContext) -> Metric {
        var base: Int
        switch token {
        case .xs: base = 0
        case .s:  base = 1
        case .m:  base = 2
        case .l:  base = 3
        case .xl: base = 4
        }
        switch ctx.density {
        case .compact:  break
        case .regular:  if base > 0 { base += 1 }
        case .spacious: if base > 0 { base += 2 }
        }
        // Terminal cells are ~2:1 (tall), so halve vertical spacing, rounding up.
        let cells = axis == .vertical ? (base + 1) / 2 : base
        return .cells(cells)
    }

    // MARK: Elevation

    /// Resolves an elevation level to terminal border/shadow presence.
    public func elevation(_ level: Elevation, in ctx: DesignContext) -> ResolvedElevation {
        switch level {
        case .flat:    return ResolvedElevation(bordered: false, shadow: false)
        case .raised:  return ResolvedElevation(bordered: true, shadow: false)
        case .overlay: return ResolvedElevation(bordered: true, shadow: true)
        }
    }

    // MARK: Motion

    /// Resolves a motion role to a duration in milliseconds (0 under reduce-motion).
    public func motion(_ role: MotionRole, in ctx: DesignContext) -> ResolvedMotion {
        if ctx.reduceMotion { return ResolvedMotion(durationMilliseconds: 0) }
        switch role {
        case .none:       return ResolvedMotion(durationMilliseconds: 0)
        case .standard:   return ResolvedMotion(durationMilliseconds: 120)
        case .emphasized: return ResolvedMotion(durationMilliseconds: 250)
        }
    }

    // MARK: State

    /// Resolves an interaction state to terminal attributes and an optional marker.
    public func style(for state: WidgetState, in ctx: DesignContext) -> ResolvedStateStyle {
        switch state {
        case .normal:   return ResolvedStateStyle()
        case .focused:  return ResolvedStateStyle(attributes: .reverse)
        case .selected: return ResolvedStateStyle(marker: ctx.glyphCapability >= .unicode ? "›" : ">")
        case .disabled: return ResolvedStateStyle(attributes: .dim)
        }
    }

    // MARK: Symbol

    /// Resolves a symbol to a glyph, choosing unicode or ASCII by capability.
    public func glyph(_ symbol: Symbol, in ctx: DesignContext) -> ResolvedGlyph {
        let mapping = symbols.mapping(for: symbol)
        let text = ctx.glyphCapability >= .unicode ? mapping.unicode : mapping.ascii
        return ResolvedGlyph(text)
    }

    // MARK: Hit target

    /// The minimum interactive hit target on a terminal — one cell for a keyboard
    /// or mouse, two cells under touch (fingers are coarser than a cursor).
    public func minHitTarget(in ctx: DesignContext) -> Metric {
        switch ctx.pointer {
        case .none, .mouse: return .cells(1)
        case .touch:        return .cells(2)
        }
    }
}
