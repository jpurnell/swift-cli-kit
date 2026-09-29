// TokenResolver.swift
// SwiftGUIKit
//
// The per-surface translation authority: turns a semantic token into concrete
// styling for a given `DesignContext`. On Apple platforms a resolver defers to
// the system (HIG baseline); on the terminal it synthesizes the nearest
// faithful equivalent.

/// Resolves semantic design tokens into concrete styling for one surface.
public protocol TokenResolver: Sendable {
    /// The active symbol set (pluggable; `DefaultSymbolSet` unless overridden).
    var symbols: any SymbolSet { get }   // LIVE: consulted by conformers in glyph(_:in:)

    /// Resolves a color role.
    func color(_ role: ColorRole, in ctx: DesignContext) -> ResolvedColor
    /// Resolves a type role.
    func font(_ role: TypeRole, in ctx: DesignContext) -> ResolvedFont
    /// Resolves a spacing token along an axis.
    func space(_ token: SpaceToken, axis: Axis, in ctx: DesignContext) -> Metric
    /// Resolves an elevation level.
    func elevation(_ level: Elevation, in ctx: DesignContext) -> ResolvedElevation
    /// Resolves a motion role (collapsed to zero when `reduceMotion` is set).
    func motion(_ role: MotionRole, in ctx: DesignContext) -> ResolvedMotion
    /// Resolves an interaction-state style.
    func style(for state: WidgetState, in ctx: DesignContext) -> ResolvedStateStyle
    /// Resolves a semantic symbol to a glyph, consulting `symbols`.
    func glyph(_ symbol: Symbol, in ctx: DesignContext) -> ResolvedGlyph
    /// The minimum interactive hit target for the surface.
    func minHitTarget(in ctx: DesignContext) -> Metric
}
