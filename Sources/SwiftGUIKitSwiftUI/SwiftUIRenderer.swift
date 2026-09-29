// SwiftUIRenderer.swift
// SwiftGUIKitSwiftUI
//
// Interprets the SwiftGUIKit scene graph into native SwiftUI views, using the
// AppleTokenResolver (HIG by deference). Containers recurse; SwiftUI does the
// layout (so `.fit` needs no measure pass — that was a terminal concern).
//
// Interaction uses TEA-style dispatch: controls emit a NodeAction via `onAction`,
// which the app handles to update its model and re-derive the scene. Bindings are
// built by static helpers so interaction is unit-testable without a running view.
//
// All interactive controls are live: checkbox → toggled, radio/tabs/dropdown/menu
// → selected, list → selected (optional), textField/textArea → textChanged. Each
// carries a stable node `id`; `onAction` is `@Sendable` so it can cross into
// SwiftUI's control closures under strict concurrency.

#if canImport(SwiftUI)
import SwiftUI
import Foundation
import SwiftCLIKit
import SwiftGUIKit

/// Renders a SwiftGUIKit ``Node`` as SwiftUI.
public struct SwiftUIRenderer {

    /// The Apple token resolver (defers to the system → HIG baseline).
    public let resolver: AppleTokenResolver

    /// Creates a renderer.
    /// - Parameter resolver: The Apple token resolver (default: `AppleTokenResolver()`).
    public init(resolver: AppleTokenResolver = AppleTokenResolver()) {
        self.resolver = resolver
    }

    /// Produces a SwiftUI view for a node (recursing through containers).
    /// - Parameters:
    ///   - node: The scene-graph node.
    ///   - onAction: Handles interactions emitted by controls (default: ignore).
    /// - Returns: A type-erased SwiftUI view.
    public func view(for node: Node, onAction: @escaping @Sendable (NodeAction) -> Void = { _ in }) -> AnyView {
        switch node {

        // MARK: Text & indicators
        case let .paragraph(text, alignment, _, color):
            return AnyView(Text(text)
                .font(resolver.font(.body))
                .foregroundStyle(resolver.color(color))
                .multilineTextAlignment(Self.textAlignment(alignment)))

        case let .gauge(ratio, label, _, _):
            // A shape-based capacity bar (not the native Gauge control, which
            // doesn't render in ImageRenderer) — reliable in window and headless,
            // and it matches the terminal's filled-bar look.
            return AnyView(gaugeBar(ratio: clamp01(ratio), label: label, tint: resolver.color(.accent)))

        case let .progressBar(current, total, showPercentage, _):
            let ratio = total > 0 ? clamp01(current / total) : 0
            return AnyView(ProgressView(value: ratio) {
                if showPercentage { Text("\(Int(ratio * 100))%") }
            })

        case let .sparkline(data, _, _):
            return AnyView(barsView(data, color: resolver.color(.accent)))

        case let .barChart(bars, _, _, _, _, _):
            return AnyView(labeledBarsView(bars, color: resolver.color(.accent)))

        // MARK: Collections
        case let .list(items, selectedIndex, _, _, _, id):
            return AnyView(List(items.indices, id: \.self,
                                selection: Self.optionalSelectionBinding(selectedIndex, id: id, onAction: onAction)) { i in
                Text(items[i])
            })

        case let .table(headers, _, cells, selectedRow, _, _, _, _, id):
            return AnyView(tableView(headers: headers, cells: cells, selectedRow: selectedRow,
                                     id: id, onAction: onAction))

        case let .tree(roots, _, selected, _, _, _, id):
            return AnyView(List(selection: Self.treeSelectionBinding(selected, id: id, onAction: onAction)) {
                OutlineGroup(roots, id: \.id, children: \.optionalChildren) { node in
                    Text(node.text)
                }
            })

        case let .menu(items, _, id, _):
            return AnyView(Menu("Menu") {
                ForEach(items.indices, id: \.self) { i in
                    Button(items[i].label) { onAction(.selected(id: id, i)) }.disabled(!items[i].enabled)
                }
            })

        // MARK: Selection controls (live)
        case let .radioGroup(options, selectedIndex, id, _):
            return AnyView(Picker("", selection: Self.selectionBinding(selectedIndex, id: id, onAction: onAction)) {
                ForEach(options.indices, id: \.self) { Text(options[$0]).tag($0) }
            }.pickerStyle(.inline).labelsHidden())

        case let .tabs(titles, activeIndex, _, _, id, _):
            return AnyView(Picker("", selection: Self.selectionBinding(activeIndex, id: id, onAction: onAction)) {
                ForEach(titles.indices, id: \.self) { Text(titles[$0]).tag($0) }
            }.pickerStyle(.segmented).labelsHidden())

        case let .dropdown(label, options, selectedIndex, _, id, _):
            return AnyView(Picker(label, selection: Self.selectionBinding(selectedIndex, id: id, onAction: onAction)) {
                ForEach(options.indices, id: \.self) { Text(options[$0]).tag($0) }
            }.pickerStyle(.menu))

        // MARK: Text entry (live)
        case let .textField(label, placeholder, text, id, _):
            return AnyView(TextField(placeholder.isEmpty ? label : placeholder,
                                     text: Self.textBinding(text, id: id, onAction: onAction))
                .onSubmit { onAction(.submitted(id: id)) })

        case let .textArea(text, _, id, _):
            return AnyView(TextEditor(text: Self.textBinding(text, id: id, onAction: onAction)))

        // MARK: Checkbox
        case let .checkbox(isChecked, label, id, color):
            return AnyView(Toggle(label, isOn: Self.toggleBinding(isChecked, id: id, onAction: onAction))
                .foregroundStyle(resolver.color(color)))

        // MARK: Misc
        case let .calendar(year, month, selectedDay, highlightedDays, _, _):
            return AnyView(calendarView(year: year, month: month, selectedDay: selectedDay,
                                        highlightedDays: highlightedDays))

        case .scrollbar:
            return AnyView(EmptyView())   // SwiftUI scrolls natively; the bar is elided

        // MARK: Containers — SwiftUI does the layout
        case let .stack(axis, spacing, children):
            let sp = resolver.spacing(spacing)
            let kids = ForEach(children.indices, id: \.self) { i in
                view(for: children[i].node, onAction: onAction)
            }
            return axis == .vertical
                ? AnyView(VStack(alignment: .leading, spacing: sp) { kids })
                : AnyView(HStack(spacing: sp) { kids })

        case .spacer:
            return AnyView(Spacer())

        case let .padding(amount, child):
            return AnyView(view(for: child, onAction: onAction).padding(resolver.spacing(amount)))

        case let .block(title, _, _, _, child):
            return AnyView(
                VStack(alignment: .leading, spacing: resolver.spacing(.s)) {
                    if let title { Text(title).font(resolver.font(.heading)) }
                    view(for: child, onAction: onAction)
                }
                .padding(resolver.spacing(.s))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(resolver.color(.separator)))
            )

        case let .form(fields, focusedIndex, errors, color):
            return AnyView(formView(fields: fields, focusedIndex: focusedIndex,
                                    errors: errors, color: color, onAction: onAction))
        }
    }

    // MARK: - Testable interaction bindings

    /// A `Binding` for a checkbox/toggle: reads the current state, and on change
    /// emits `.toggled(id:_:)` through `onAction`.
    public static func toggleBinding(
        _ isChecked: Bool, id: String, onAction: @escaping @Sendable (NodeAction) -> Void
    ) -> Binding<Bool> {
        Binding(get: { isChecked }, set: { onAction(.toggled(id: id, $0)) })
    }

    /// A `Binding` for a text field/area: reads the current text, and on change
    /// emits `.textChanged(id:_:)` through `onAction`.
    public static func textBinding(
        _ text: String, id: String, onAction: @escaping @Sendable (NodeAction) -> Void
    ) -> Binding<String> {
        Binding(get: { text }, set: { onAction(.textChanged(id: id, $0)) })
    }

    /// A `Binding` for a single-select control: reads the index, and on change
    /// emits `.selected(id:_:)` through `onAction`.
    public static func selectionBinding(
        _ index: Int, id: String, onAction: @escaping @Sendable (NodeAction) -> Void
    ) -> Binding<Int> {
        Binding(get: { index }, set: { onAction(.selected(id: id, $0)) })
    }

    /// A `Binding<Int?>` for an optional single-select control (e.g. a `List`).
    /// Emits `.selected(id:_:)` when a row is chosen.
    public static func optionalSelectionBinding(
        _ index: Int?, id: String, onAction: @escaping @Sendable (NodeAction) -> Void
    ) -> Binding<Int?> {
        Binding(get: { index }, set: { if let value = $0 { onAction(.selected(id: id, value)) } })
    }

    /// A `Binding<String?>` for a node-identity selection (e.g. a tree's
    /// `OutlineGroup` rows). Emits `.nodeSelected(id:_:)` with the chosen node's
    /// identifier.
    public static func treeSelectionBinding(
        _ nodeID: String?, id: String, onAction: @escaping @Sendable (NodeAction) -> Void
    ) -> Binding<String?> {
        Binding(get: { nodeID }, set: { if let value = $0 { onAction(.nodeSelected(id: id, value)) } })
    }

    // MARK: - Helpers

    static func textAlignment(_ alignment: Paragraph.Alignment) -> TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func clamp01(_ v: Double) -> Double { Swift.min(Swift.max(v, 0), 1) }

    /// A shape-based capacity bar with an optional centered label.
    @ViewBuilder
    private func gaugeBar(ratio: Double, label: String?, tint: SwiftUI.Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(tint.opacity(0.22))
                RoundedRectangle(cornerRadius: 4).fill(tint)
                    .frame(width: Swift.max(0, geo.size.width * ratio))
                if let label {
                    Text(label)
                        .font(.caption).bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private func barsView(_ data: [Double], color: SwiftUI.Color) -> some View {
        let maxVal = Swift.max(data.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(data.indices, id: \.self) { i in
                Rectangle().fill(color)
                    .frame(width: 3, height: 40 * (Swift.max(data[i], 0) / maxVal))
            }
        }
        .frame(height: 40, alignment: .bottom)
    }

    @ViewBuilder
    private func labeledBarsView(_ bars: [BarValue], color: SwiftUI.Color) -> some View {
        let maxVal = Swift.max(bars.map(\.value).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(bars.indices, id: \.self) { i in
                VStack(spacing: 2) {
                    Rectangle().fill(color)
                        .frame(width: 16, height: 60 * (Swift.max(bars[i].value, 0) / maxVal))
                    Text(bars[i].label).font(.caption)
                }
            }
        }
    }

    /// The Sunday-first grid position of a month: how many blank leading cells
    /// precede day 1, and how many days the month has. Uses the Gregorian
    /// `Foundation.Calendar` exactly as the terminal `CalendarView` does, so both
    /// surfaces lay the month out identically. Deterministic — no current date.
    static func monthLayout(year: Int, month: Int) -> (startOffset: Int, daysInMonth: Int) {
        let calendar = Foundation.Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let daysRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return (0, 30)
        }
        let weekday = calendar.component(.weekday, from: firstOfMonth)  // 1 = Sunday
        let startOffset = ((weekday - calendar.firstWeekday) + 7) % 7
        return (startOffset, daysRange.count)
    }

    /// A human month title, e.g. "July 2026".
    static func monthTitle(year: Int, month: Int) -> String {
        let names = ["", "January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        let name = (1...12).contains(month) ? names[month] : "\(month)"
        return "\(name) \(year)"
    }

    /// A month calendar as a 7-column grid: weekday headers, blank leading cells,
    /// then day numbers. The selected day fills with the accent color; highlighted
    /// days render bold — matching the terminal's reverse/bold treatment.
    @ViewBuilder
    private func calendarView(year: Int, month: Int, selectedDay: Int?,
                              highlightedDays: Set<Int>) -> some View {
        let layout = Self.monthLayout(year: year, month: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        VStack(alignment: .leading, spacing: resolver.spacing(.xs)) {
            Text(Self.monthTitle(year: year, month: month)).font(resolver.font(.heading))
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"], id: \.self) { day in
                    Text(day).font(resolver.font(.caption)).foregroundStyle(resolver.color(.secondaryLabel))
                }
                ForEach(0..<layout.startOffset, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(1...Swift.max(layout.daysInMonth, 1), id: \.self) { day in
                    dayCell(day, selected: selectedDay == day, highlighted: highlightedDays.contains(day))
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Int, selected: Bool, highlighted: Bool) -> some View {
        Text("\(day)")
            .font(resolver.font(.body))
            .fontWeight(highlighted ? .bold : .regular)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(selected ? resolver.color(.accent) : SwiftUI.Color.clear)
            .foregroundStyle(selected ? AnyShapeStyle(SwiftUI.Color.white) : AnyShapeStyle(resolver.color(.label)))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// A labeled-field form: each field is a caption label over a bound text field,
    /// with its validation error (keyed by field id) shown beneath in the
    /// destructive color. The focused field is bordered for emphasis. Native focus
    /// is user-driven, so `focusedIndex` drives only the visual emphasis here.
    @ViewBuilder
    private func formView(fields: [FormFieldData], focusedIndex: Int, errors: [String: String],
                          color: ColorRole, onAction: @escaping @Sendable (NodeAction) -> Void) -> some View {
        VStack(alignment: .leading, spacing: resolver.spacing(.m)) {
            ForEach(fields.indices, id: \.self) { i in
                let field = fields[i]
                VStack(alignment: .leading, spacing: resolver.spacing(.xs)) {
                    Text(field.label)
                        .font(resolver.font(.caption))
                        .foregroundStyle(resolver.color(.secondaryLabel))
                    TextField("", text: Self.textBinding(field.value, id: field.id, onAction: onAction))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onAction(.submitted(id: field.id)) }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(resolver.color(.accent), lineWidth: i == focusedIndex ? 2 : 0)
                        )
                    if let error = errors[field.id] {
                        Text(error)
                            .font(resolver.font(.caption))
                            .foregroundStyle(resolver.color(.destructive))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tableView(headers: [String], cells: [[String]], selectedRow: Int?,
                           id: String, onAction: @escaping @Sendable (NodeAction) -> Void) -> some View {
        // A non-scrolling stack of equal-width rows — not a `List`. A List needs a
        // bounded height and collapses to nothing inside a page `ScrollView`; this
        // composes cleanly inside one. Selection is a tap gesture (not List
        // selection), so the row still emits `.selected` and highlights.
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ForEach(headers.indices, id: \.self) { c in
                    Text(headers[c]).font(resolver.font(.heading))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)
            Divider()
            ForEach(cells.indices, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(cells[r].indices, id: \.self) { c in
                        Text(cells[r][c]).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(selectedRow == r ? resolver.color(.accent).opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { onAction(.selected(id: id, r)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bridges the concrete tree form to `OutlineGroup`, which wants optional children.
extension TreeDisplayNode {
    /// Children, or `nil` for a leaf (so `OutlineGroup` renders it without a disclosure).
    var optionalChildren: [TreeDisplayNode]? { children.isEmpty ? nil : children }
}
#endif
