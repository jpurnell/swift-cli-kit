// Node.swift
// SwiftGUIKit
//
// The semantic scene graph: a value that describes *what* a UI is, never *how*
// it is drawn. Renderers interpret it per surface. Phase 0 defines only the
// cases the proving-slice widget (Gauge) needs; the enum grows one case per
// widget in Phase 1.
//
// Node is intentionally non-generic in Phase 0 (no interactive cases yet). It
// gains a `Message` type parameter when the first interactive widget lands.

import SwiftCLIKit

/// A semantic UI node. Carries only design-token intent — never literal colors,
/// characters, or sizes.
public indirect enum Node: Sendable, Equatable {
    /// A horizontal gauge. `fill`/`track` are semantic color roles resolved per
    /// surface; the ratio is stored raw and clamped at render time (as in the
    /// legacy renderer).
    case gauge(ratio: Double, label: String?, fill: ColorRole, track: ColorRole)

    /// A progress bar. Monochrome (one `color` role for both bar and track, as in
    /// the legacy widget); `current`/`total` are raw, resolved to a ratio, an
    /// optional percentage label, and a zero-total fallback at render time.
    case progressBar(current: Double, total: Double, showPercentage: Bool, color: ColorRole)

    /// A sparkline. Monochrome; `data`/`max` are raw and scaled to per-column
    /// block heights at render time.
    case sparkline(data: [Double], max: Double?, color: ColorRole)

    /// A vertical bar chart. Monochrome in v1 (one `color` role for all bars);
    /// per-bar styling can arrive later without changing this case's shape.
    case barChart(bars: [BarValue], barWidth: Int, barGap: Int, max: Double?, showValues: Bool, color: ColorRole)

    /// A selectable, scrollable list. Selection/scroll are **state data**, not
    /// messages, so the node stays non-generic; the highlighted row is resolved
    /// through the `.focused` ``WidgetState``. Monochrome item styling in v1.
    case list(items: [String], selectedIndex: Int?, scrollOffset: Int, itemColor: ColorRole, showScrollbar: Bool, id: String)

    /// A checkbox. The box `[ ]` is the widget's frame; the mark is the `check`
    /// symbol (from the active ``SymbolSet``), so the ASCII floor reproduces the
    /// legacy `[x]` and unicode renders `[✓]`. `id` identifies it for interaction
    /// (empty when non-interactive); the terminal renderer ignores it.
    case checkbox(isChecked: Bool, label: String, id: String, color: ColorRole)

    /// A single-select radio group. The parens `( )` are the widget's frame; the
    /// mark is a `radioOn`/`radioOff` symbol. The unselected option renders an
    /// open circle (a deliberate improvement over the legacy empty `( )`).
    case radioGroup(options: [String], selectedIndex: Int, id: String, color: ColorRole)

    /// A hierarchical tree. The generic value type and `renderNode` closure are
    /// resolved at projection into a concrete ``TreeDisplayNode`` tree of display
    /// strings; expansion/selection/scroll are carried as state, like ``list``.
    /// `id` identifies it for interaction (empty when non-interactive); selecting a
    /// row emits `.nodeSelected(id:_:)` with the node's identifier.
    case tree(roots: [TreeDisplayNode], expanded: Set<String>, selected: String?,
              scrollOffset: Int, indentWidth: Int, itemColor: ColorRole, id: String)

    /// A horizontal tab bar. The active tab renders as `font(.heading)` (bold),
    /// inactive tabs as `font(.body)` — matching the legacy default styles.
    case tabs(titles: [String], activeIndex: Int, separator: String, underline: Character?, id: String, color: ColorRole)

    /// A vertical menu. Visible rows match the legacy widget; when items exceed
    /// the frame height the last row shows an `overflow` glyph (a UX improvement
    /// over the legacy silent truncation).
    case menu(items: [MenuEntry], selectedIndex: Int, id: String, color: ColorRole)

    /// A table. The generic `Row` type and per-column render closures are resolved
    /// at projection into concrete `cells` (rows × columns of strings); the header
    /// renders as `font(.heading)` and any sort column shows a `sort` glyph.
    case table(headers: [String], widths: [Layout.Constraint], cells: [[String]],
               selectedRow: Int?, scrollOffset: Int, sort: TableSort?,
               headerColor: ColorRole, rowColor: ColorRole, id: String)

    /// A block of wrapped, aligned text. Rendered by reconstructing the widget
    /// with the token-resolved foreground color.
    case paragraph(text: String, alignment: Paragraph.Alignment, wrap: Bool, color: ColorRole)

    /// A scrollbar. `trackColor`/`thumbColor` resolve the track and thumb styles.
    case scrollbar(orientation: Scrollbar.Orientation, contentLength: Int, viewportSize: Int,
                   offset: Int, trackColor: ColorRole, thumbColor: ColorRole)

    /// A dropdown (collapsed or expanded). Rendered in its resting state; focus is
    /// deferred to the interaction phase.
    case dropdown(label: String, options: [String], selectedIndex: Int, isExpanded: Bool, id: String, color: ColorRole)

    /// A single-line text field (with border, label, and placeholder). Rendered in
    /// its resting (unfocused) state.
    case textField(label: String, placeholder: String, text: String, id: String, color: ColorRole)

    /// A multi-line text area. Rendered in its resting (unfocused) state.
    case textArea(text: String, scrollOffset: Int, id: String, color: ColorRole)

    /// A month calendar. The selected day resolves via `.focused` (reverse) and
    /// highlighted days via `font(.heading)` (bold) — matching the legacy defaults.
    case calendar(year: Int, month: Int, selectedDay: Int?, highlightedDays: Set<Int>,
                  showWeekNumbers: Bool, color: ColorRole)

    // MARK: Containers

    /// Lays children out along an axis, dividing space by each child's
    /// ``SizeConstraint`` and inserting `spacing` between them.
    case stack(axis: Axis, spacing: SpaceToken, children: [StackChild])

    /// Flexible empty space — occupies its allocated rect and draws nothing.
    case spacer

    /// Insets a single child by a spacing token on each edge (halved on the
    /// vertical axis for the 2:1 cell aspect, like all spacing).
    case padding(_ amount: SpaceToken, child: Node)

    /// A bordered container wrapping a child — the `Block` port. Rendered by
    /// reconstructing `Block` (which draws the border and returns the inner
    /// frame) and recursing into that inner frame.
    case block(title: String?, borders: BorderSet, boxDrawing: BoxDrawing,
               titleAlignment: Paragraph.Alignment, child: Node)

    /// A form (labeled fields + focus + validation errors). Its label/value/error
    /// layout is bespoke, so it is a reconstruct-and-call composite rather than a
    /// decomposition into containers (see the Container Nodes proposal §6 fallback).
    case form(fields: [FormFieldData], focusedIndex: Int, errors: [String: String], color: ColorRole)
}

/// A form field's render-relevant content (id / label / value). Validation rules
/// don't affect rendering, so they are not carried.
public struct FormFieldData: Sendable, Equatable {
    /// The field identifier (matches error keys).
    public let id: String
    /// The display label.
    public let label: String
    /// The current value.
    public let value: String

    /// Creates form field data.
    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

/// How a stack child claims space along the stack axis. **SwiftGUIKit-owned on
/// purpose** so the intrinsic-sizing follow-up can add `.fit` as a purely
/// additive case (see the Container Nodes proposal §5.2).
public enum SizeConstraint: Sendable, Equatable {
    /// An exact number of cells along the stack axis.
    case fixed(Int)
    /// A weight; flex children share the leftover space proportionally.
    case flex(Int)
    /// Size to the child's measured intrinsic content (Phase D). Resolved to
    /// `.fixed(measured)` before layout, so it composes with `.fixed`/`.flex`.
    case fit
}

/// A child in a ``Node/stack(axis:spacing:children:)``, paired with how it claims
/// space along the stack axis.
public struct StackChild: Sendable, Equatable {
    /// The child node.
    public let node: Node
    /// How the child claims space along the stack axis.
    public let size: SizeConstraint

    /// Creates a stack child.
    /// - Parameters:
    ///   - node: The child node.
    ///   - size: The size constraint (default: `.flex(1)`).
    public init(_ node: Node, size: SizeConstraint = .flex(1)) {
        self.node = node
        self.size = size
    }
}

/// A table's sort indicator: which column and direction.
public struct TableSort: Sendable, Equatable {
    /// The sorted column index.
    public let column: Int
    /// Whether the sort is ascending.
    public let ascending: Bool

    /// Creates a sort indicator.
    public init(column: Int, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

/// A single menu item's semantic content (no literal styling).
public struct MenuEntry: Sendable, Equatable {
    /// The label text.
    public let label: String
    /// An optional right-aligned key hint.
    public let keyHint: String?
    /// Whether the item is enabled.
    public let enabled: Bool

    /// Creates a menu entry.
    public init(label: String, keyHint: String? = nil, enabled: Bool = true) {
        self.label = label
        self.keyHint = keyHint
        self.enabled = enabled
    }
}

/// A single bar's semantic content in a ``Node/barChart(bars:barWidth:barGap:max:showValues:color:)``
/// — label and value only, no literal styling.
public struct BarValue: Sendable, Equatable {
    /// The label displayed below the bar.
    public let label: String
    /// The numeric value determining bar height.
    public let value: Double

    /// Creates a semantic bar value.
    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}
