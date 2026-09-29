// Resolved.swift
// SwiftGUIKit
//
// Concrete results a `TokenResolver` produces. These are surface-neutral value
// types; the terminal fields (Color / CellAttributes) come from SwiftCLIKit.

import SwiftCLIKit

/// A measurement in a surface-appropriate unit.
public struct Metric: Sendable, Equatable {
    /// The unit a metric is expressed in.
    public enum Unit: Sendable, Equatable {
        case cells
        case points          // LIVE: public metric-unit vocabulary
        case pixels          // LIVE: public metric-unit vocabulary
    }
    /// The scalar value.
    public let value: Int
    /// The unit `value` is expressed in.
    public let unit: Unit

    /// Creates a metric.
    public init(_ value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    /// A metric expressed in terminal cells.
    public static func cells(_ value: Int) -> Metric { Metric(value, unit: .cells) }
}

/// A resolved color: a terminal `Color`, any emphasis attributes, and — on the
/// mono floor — a symbol/label prefix so status is never conveyed by color alone.
public struct ResolvedColor: Sendable, Equatable {
    /// The concrete terminal color (may be `.default`).
    public var color: Color
    /// Emphasis attributes (e.g. `.bold` for accent on the mono floor).
    public var attributes: CellAttributes
    /// A prefix that carries meaning when color is unavailable.
    public var monoPrefix: String?

    /// Creates a resolved color.
    public init(color: Color, attributes: CellAttributes = [], monoPrefix: String? = nil) {
        self.color = color
        self.attributes = attributes
        self.monoPrefix = monoPrefix
    }
}

/// A resolved type role, expressed for the terminal as weight/dim/case.
public struct ResolvedFont: Sendable, Equatable {
    /// Whether the role uppercases its text.
    public enum CaseTransform: Sendable, Equatable {
        case none
        case upper           // LIVE: public case-transform vocabulary
    }
    /// Emphasis attributes (bold / dim).
    public var attributes: CellAttributes
    /// A case transformation applied to the text.
    public var caseTransform: CaseTransform

    /// Creates a resolved font.
    public init(attributes: CellAttributes = [], caseTransform: CaseTransform = .none) {
        self.attributes = attributes
        self.caseTransform = caseTransform
    }
}

/// A resolved glyph — the chosen textual representation of a `Symbol`.
public struct ResolvedGlyph: Sendable, Equatable {
    /// The glyph text.
    public var text: String
    /// Creates a resolved glyph.
    public init(_ text: String) { self.text = text }
}

/// A resolved interaction-state style.
public struct ResolvedStateStyle: Sendable, Equatable {
    /// Attributes applied for the state (e.g. `.reverse` for focus).
    public var attributes: CellAttributes
    /// An optional leading marker (e.g. a selection indicator).
    public var marker: String?

    /// Creates a resolved state style.
    public init(attributes: CellAttributes = [], marker: String? = nil) {
        self.attributes = attributes
        self.marker = marker
    }
}

/// A resolved elevation, expressed for the terminal as border/shadow presence.
public struct ResolvedElevation: Sendable, Equatable {
    /// Whether a border is drawn.
    public var bordered: Bool
    /// Whether a drop shadow is drawn.
    public var shadow: Bool
    /// Creates a resolved elevation.
    public init(bordered: Bool, shadow: Bool) {
        self.bordered = bordered
        self.shadow = shadow
    }
}

/// A resolved motion, expressed as a duration in milliseconds (0 == none).
public struct ResolvedMotion: Sendable, Equatable {
    /// The animation duration in milliseconds; 0 means no animation.
    public var durationMilliseconds: Int
    /// Creates a resolved motion.
    public init(durationMilliseconds: Int) {
        self.durationMilliseconds = durationMilliseconds
    }
}
