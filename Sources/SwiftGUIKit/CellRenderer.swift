// CellRenderer.swift
// SwiftGUIKit
//
// Interprets a semantic `Node` for the terminal surface: it resolves each node's
// token intent through a `TokenResolver` + `DesignContext`, then draws into a
// SwiftCLIKit `Frame`. Phase 0 handles only `.gauge`; the switch grows with the
// `Node` enum.

import SwiftCLIKit

/// Renders a semantic ``Node`` tree onto a terminal cell grid.
public struct CellRenderer: Sendable {
    /// The token resolver supplying concrete styling for this surface.
    public let resolver: any TokenResolver
    /// The design context resolutions are computed against.
    public let context: DesignContext

    /// Creates a cell renderer.
    /// - Parameters:
    ///   - resolver: The surface's token resolver (e.g. ``TerminalTokenResolver``).
    ///   - context: The active ``DesignContext``.
    public init(resolver: any TokenResolver, context: DesignContext) {
        self.resolver = resolver
        self.context = context
    }

    /// Renders a node into the given frame.
    /// - Parameters:
    ///   - node: The semantic node to render.
    ///   - frame: The frame to draw into.
    public func render(_ node: Node, into frame: inout Frame) {
        switch node {
        case let .gauge(ratio, label, fill, track):
            renderGauge(ratio: ratio, label: label, fill: fill, track: track, into: &frame)
        case let .progressBar(current, total, showPercentage, color):
            renderProgressBar(current: current, total: total, showPercentage: showPercentage,
                              color: color, into: &frame)
        case let .sparkline(data, max, color):
            SparklineGeometry(data: data, max: max, width: frame.rect.width, height: frame.rect.height)
                .draw(into: &frame, style: cellStyle(for: color))
        case let .barChart(bars, barWidth, barGap, max, showValues, color):
            let style = cellStyle(for: color)
            BarChartRenderer.draw(
                into: &frame,
                bars: bars.map { ($0.label, $0.value) },
                barWidth: barWidth, barGap: barGap, max: max, showValues: showValues,
                style: { _ in style })
        case let .list(items, selectedIndex, scrollOffset, itemColor, _, _):
            renderList(items: items, selectedIndex: selectedIndex, scrollOffset: scrollOffset,
                       itemColor: itemColor, into: &frame)
        case let .checkbox(isChecked, label, _, color):   // id is a SwiftUI-side concern
            let mark = isChecked ? resolver.glyph(.check, in: context).text : " "
            let indicator = "[" + mark + "]"
            let text = label.isEmpty ? indicator : "\(indicator) \(label)"
            let style = cellStyle(for: color)
            frame.writeText(text, x: 0, y: 0, fg: style.fg, bg: style.bg, attributes: style.attributes)
        case let .radioGroup(options, selectedIndex, _, color):
            let style = cellStyle(for: color)
            for (index, option) in options.enumerated() {
                let mark = resolver.glyph(index == selectedIndex ? .radioOn : .radioOff, in: context).text
                frame.writeText("(\(mark)) \(option)", x: 0, y: index,
                                fg: style.fg, bg: style.bg, attributes: style.attributes)
            }
        case let .tree(roots, expanded, selected, scrollOffset, indentWidth, itemColor, _):
            let normal = cellStyle(for: itemColor)
            // Selected row = focused cursor, same as List.
            let focusAttrs = resolver.style(for: .focused, in: context).attributes
            let highlight = CellStyle(fg: normal.fg, bg: normal.bg, attributes: normal.attributes.union(focusAttrs))
            TreeRenderer.draw(
                into: &frame, roots: roots, expanded: expanded, selected: selected,
                scrollOffset: scrollOffset, indentWidth: indentWidth,
                normalStyle: normal, highlightStyle: highlight)
        case let .tabs(titles, activeIndex, separator, underline, _, color):
            let normal = cellStyle(for: color)
            // Active tab = heading (bold); inactive = body — matches legacy defaults.
            let active = CellStyle(fg: normal.fg, bg: normal.bg,
                                   attributes: normal.attributes.union(resolver.font(.heading, in: context).attributes))
            let inactive = CellStyle(fg: normal.fg, bg: normal.bg,
                                     attributes: normal.attributes.union(resolver.font(.body, in: context).attributes))
            TabsRenderer.draw(
                into: &frame, titles: titles, activeIndex: activeIndex, separator: separator,
                underline: underline, activeStyle: active, inactiveStyle: inactive)
        case let .menu(items, selectedIndex, _, color):
            let normal = cellStyle(for: color)
            let highlight = CellStyle(fg: normal.fg, bg: normal.bg,
                                      attributes: normal.attributes.union(resolver.style(for: .focused, in: context).attributes))
            let disabled = CellStyle(fg: normal.fg, bg: normal.bg,
                                     attributes: normal.attributes.union(resolver.style(for: .disabled, in: context).attributes))
            MenuRenderer.draw(
                into: &frame,
                items: items.map { ($0.label, $0.keyHint, $0.enabled) },
                selectedIndex: selectedIndex,
                normalStyle: normal, highlightStyle: highlight, disabledStyle: disabled,
                showOverflow: true, overflowText: resolver.glyph(.overflow, in: context).text)
        case let .table(headers, widths, cells, selectedRow, scrollOffset, sort, headerColor, rowColor, _):
            let rowNormal = cellStyle(for: rowColor)
            let highlight = CellStyle(fg: rowNormal.fg, bg: rowNormal.bg,
                                      attributes: rowNormal.attributes.union(resolver.style(for: .focused, in: context).attributes))
            let headerBase = cellStyle(for: headerColor)
            let headerStyle = CellStyle(fg: headerBase.fg, bg: headerBase.bg,
                                        attributes: headerBase.attributes.union(resolver.font(.heading, in: context).attributes))
            TableRenderer.draw(
                into: &frame, headers: headers, widths: widths, cells: cells,
                selectedRow: selectedRow, scrollOffset: scrollOffset,
                sortIndicator: sort.map { (column: $0.column, ascending: $0.ascending) },
                sortAscendingGlyph: resolver.glyph(.sortAscending, in: context).text,
                sortDescendingGlyph: resolver.glyph(.sortDescending, in: context).text,
                normalStyle: rowNormal, highlightStyle: highlight, headerStyle: headerStyle)
        case let .paragraph(text, alignment, wrap, color):
            // Reconstruct the widget with the token-resolved color and reuse its render.
            let style = cellStyle(for: color)
            Paragraph(text: text, alignment: alignment, wrap: wrap)
                .render(into: &frame, fg: style.fg, bg: style.bg)
        case let .scrollbar(orientation, contentLength, viewportSize, offset, trackColor, thumbColor):
            Scrollbar(orientation: orientation, contentLength: contentLength, viewportSize: viewportSize,
                      offset: offset, trackStyle: cellStyle(for: trackColor), thumbStyle: cellStyle(for: thumbColor))
                .render(into: &frame)
        case let .dropdown(label, options, selectedIndex, isExpanded, _, _):
            var dropdown = Dropdown(label: label, options: options, selectedIndex: selectedIndex)
            dropdown.isExpanded = isExpanded
            dropdown.render(into: &frame, focused: false)   // focus deferred
        case let .textField(label, placeholder, text, _, color):
            TextField(label: label, placeholder: placeholder, text: text, style: cellStyle(for: color))
                .render(into: &frame, focused: false)
        case let .textArea(text, scrollOffset, _, _):
            var area = TextArea(text: text)
            area.scrollOffset = scrollOffset
            area.render(into: &frame, focused: false)
        case let .calendar(year, month, selectedDay, highlightedDays, showWeekNumbers, color):
            let base = cellStyle(for: color)
            let selected = CellStyle(fg: base.fg, bg: base.bg,
                                     attributes: base.attributes.union(resolver.style(for: .focused, in: context).attributes))
            let highlight = CellStyle(fg: base.fg, bg: base.bg,
                                      attributes: base.attributes.union(resolver.font(.heading, in: context).attributes))
            CalendarView(year: year, month: month, selectedDay: selectedDay, highlightedDays: highlightedDays,
                         selectedStyle: selected, highlightStyle: highlight, showWeekNumbers: showWeekNumbers)
                .render(into: &frame)
        case let .stack(axis, spacing, children):
            let gap = resolver.space(spacing, axis: axis, in: context).value
            let crossExtent = axis == .vertical ? frame.rect.width : frame.rect.height
            let mainExtent = axis == .vertical ? frame.rect.height : frame.rect.width
            // Resolve .fit children to .fixed(measured) before layout (Phase D).
            let sizes: [SizeConstraint] = children.map { child in
                guard case .fit = child.size else { return child.size }
                let avail = axis == .vertical
                    ? Size(width: crossExtent, height: mainExtent)
                    : Size(width: mainExtent, height: crossExtent)
                let m = measure(child.node, available: avail)
                return .fixed(axis == .vertical ? m.height : m.width)
            }
            let rects = StackLayout.rects(in: frame.rect, axis: axis, gap: gap, sizes: sizes)
            for (child, rect) in zip(children, rects) {
                var sub = frame.subFrame(rect)
                render(child.node, into: &sub)   // recursion
            }
        case .spacer:
            break   // occupies its rect, draws nothing
        case let .padding(amount, child):
            let h = resolver.space(amount, axis: .horizontal, in: context).value
            let v = resolver.space(amount, axis: .vertical, in: context).value
            let r = frame.rect
            let inner = Rect(x: r.x + h, y: r.y + v,
                             width: Swift.max(0, r.width - 2 * h), height: Swift.max(0, r.height - 2 * v))
            var sub = frame.subFrame(inner)
            render(child, into: &sub)   // recursion
        case let .block(title, borders, boxDrawing, titleAlignment, child):
            // Reconstruct-and-call: Block draws the border and returns the inner frame.
            var inner = Block(title: title, borders: borders, boxDrawing: boxDrawing,
                              titleAlignment: titleAlignment).render(into: &frame)
            render(child, into: &inner)   // recursion into the inner frame
        case let .form(fields, focusedIndex, errors, _):
            // Reconstruct-and-call: Form's label/value/error layout is bespoke.
            var form = Form(fields: fields.map { Form.Field(id: $0.id, label: $0.label, value: $0.value) })
            form.focusedFieldIndex = focusedIndex
            form.errors = errors
            form.render(into: &frame)
        }
    }

    // MARK: - List

    private func renderList(
        items: [String], selectedIndex: Int?, scrollOffset: Int, itemColor: ColorRole, into frame: inout Frame
    ) {
        let normal = cellStyle(for: itemColor)
        // The highlighted (selected) row is the focused cursor: normal styling
        // plus the `.focused` state's attributes (reverse video on a terminal).
        let focusAttrs = resolver.style(for: .focused, in: context).attributes
        let highlight = CellStyle(fg: normal.fg, bg: normal.bg, attributes: normal.attributes.union(focusAttrs))
        ListRenderer.draw(
            into: &frame,
            items: items,
            state: ListState(selectedIndex: selectedIndex, scrollOffset: scrollOffset),
            normalStyle: { _ in normal },
            highlightStyle: highlight
        )
    }

    // MARK: - Gauge

    // Block characters are intrinsic to how a gauge reads on a terminal, not a
    // themable color/spacing literal; they match the legacy Gauge defaults.
    private static let filledChar: Character = "█"
    private static let trackChar: Character = "░"

    private func renderGauge(
        ratio: Double, label: String?, fill: ColorRole, track: ColorRole, into frame: inout Frame
    ) {
        let width = frame.rect.width
        guard width > 0 else { return }
        GaugeGeometry(width: width, ratio: ratio, labelLength: label?.count)
            .draw(
                into: &frame,
                filledChar: Self.filledChar,
                filledStyle: cellStyle(for: fill),
                unfilledChar: Self.trackChar,
                unfilledStyle: cellStyle(for: track),
                label: label
            )
    }

    // MARK: - ProgressBar

    private func renderProgressBar(
        current: Double, total: Double, showPercentage: Bool, color: ColorRole, into frame: inout Frame
    ) {
        let style = cellStyle(for: color)
        switch ProgressBarLayout(current: current, total: total, showPercentage: showPercentage).content {
        case .zeroTotal(let label):
            if let label { frame.writeText(label, x: 0, y: 0) }
        case .bar(let ratio, let label):
            let width = frame.rect.width
            guard width > 0 else { return }
            // Monochrome: bar and track share one style, matching the legacy widget.
            GaugeGeometry(width: width, ratio: ratio, labelLength: label?.count)
                .draw(
                    into: &frame,
                    filledChar: Self.filledChar,
                    filledStyle: style,
                    unfilledChar: Self.trackChar,
                    unfilledStyle: style,
                    label: label
                )
        }
    }

    /// Resolves a color role to a concrete `CellStyle` on the active context.
    private func cellStyle(for role: ColorRole) -> CellStyle {
        let resolved = resolver.color(role, in: context)
        return CellStyle(fg: resolved.color, bg: .default, attributes: resolved.attributes)
    }
}
