// Measure.swift
// SwiftGUIKit
//
// Intrinsic sizing (Phase D). `measure` reports a node's natural size given the
// space available. Container rendering measures `.fit` children and pins them to
// `.fixed(measured)` before layout, so `StackLayout` stays unchanged. Most arms
// are exact and content-driven; a few (calendar/form/textField) use the widget's
// fixed structural height.

import SwiftCLIKit

/// A width/height measurement in cells.
public struct Size: Sendable, Equatable {
    /// The width in cells.
    public var width: Int
    /// The height in cells.
    public var height: Int
    /// Creates a size.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public extension CellRenderer {

    /// The node's natural size given the space available.
    func measure(_ node: Node, available: Size) -> Size {
        switch node {
        case .gauge, .progressBar:
            return Size(width: available.width, height: 1)

        case .sparkline, .scrollbar, .barChart:
            return available   // fill widgets have no intrinsic content size

        case let .list(items, _, _, _, _, _):
            return Size(width: available.width, height: Swift.min(items.count, available.height))

        case let .menu(items, _, _, _):
            return Size(width: available.width, height: Swift.min(items.count, available.height))

        case let .radioGroup(options, _, _, _):
            return Size(width: available.width, height: Swift.min(options.count, available.height))

        case let .checkbox(_, label, _, _):
            let w = label.isEmpty ? 3 : 3 + 1 + label.count   // "[x]" + " " + label
            return Size(width: Swift.min(w, available.width), height: 1)

        case let .tabs(titles, _, separator, underline, _, _):
            let w = titles.reduce(0) { $0 + $1.count } + Swift.max(0, titles.count - 1) * separator.count
            return Size(width: Swift.min(w, available.width), height: underline != nil ? 2 : 1)

        case let .table(_, _, cells, _, _, _, _, _, _):
            return Size(width: available.width, height: Swift.min(1 + cells.count, available.height))

        case let .tree(roots, expanded, _, _, _, _, _):
            return Size(width: available.width,
                        height: Swift.min(Self.treeVisibleCount(roots, expanded), available.height))

        case let .paragraph(text, alignment, wrap, _):
            let h = Paragraph(text: text, alignment: alignment, wrap: wrap)
                .wrappedLines(width: available.width).count
            return Size(width: available.width, height: Swift.min(h, available.height))

        case let .dropdown(_, options, _, isExpanded, _, _):
            return Size(width: available.width, height: isExpanded ? 1 + options.count : 1)

        case .textField:
            return Size(width: available.width, height: 3)   // bordered box

        case let .textArea(text, _, _, _):
            let lines = text.isEmpty ? 1 : text.lines.count
            return Size(width: available.width, height: Swift.min(lines, available.height))

        case .calendar:
            return Size(width: available.width, height: Swift.min(8, available.height))

        case let .form(fields, _, errors, _):
            return Size(width: available.width, height: Swift.min(fields.count * 2 + errors.count, available.height))

        case let .stack(axis, spacing, children):
            return measureStack(axis: axis, spacing: spacing, children: children, available: available)

        case .spacer:
            return Size(width: 0, height: 0)

        case let .padding(amount, child):
            let h = resolver.space(amount, axis: .horizontal, in: context).value
            let v = resolver.space(amount, axis: .vertical, in: context).value
            let inner = measure(child, available: Size(width: Swift.max(0, available.width - 2 * h),
                                                       height: Swift.max(0, available.height - 2 * v)))
            return Size(width: inner.width + 2 * h, height: inner.height + 2 * v)

        case let .block(_, borders, _, _, child):
            let hInset = (borders.contains(.left) ? 1 : 0) + (borders.contains(.right) ? 1 : 0)
            let vInset = (borders.contains(.top) ? 1 : 0) + (borders.contains(.bottom) ? 1 : 0)
            let inner = measure(child, available: Size(width: Swift.max(0, available.width - hInset),
                                                       height: Swift.max(0, available.height - vInset)))
            return Size(width: inner.width + hInset, height: inner.height + vInset)
        }
    }

    /// A stack's own intrinsic size: fixed children contribute their fixed size,
    /// others their measured size; plus inter-child spacing.
    private func measureStack(axis: Axis, spacing: SpaceToken, children: [StackChild], available: Size) -> Size {
        // Base case for the measure/measureStack cycle: an empty stack has no
        // children to recurse into and contributes no size.
        guard !children.isEmpty else { return Size(width: 0, height: 0) }
        let gap = resolver.space(spacing, axis: axis, in: context).value
        var mainSum = 0
        var crossMax = 0
        for child in children {
            let m = measure(child.node, available: available)
            let measuredMain = axis == .vertical ? m.height : m.width
            let measuredCross = axis == .vertical ? m.width : m.height
            if case .fixed(let k) = child.size {
                mainSum += k
            } else {
                mainSum += measuredMain
            }
            crossMax = Swift.max(crossMax, measuredCross)
        }
        let totalGap = Swift.max(0, children.count - 1) * gap
        return axis == .vertical
            ? Size(width: crossMax, height: mainSum + totalGap)
            : Size(width: mainSum + totalGap, height: crossMax)
    }

    /// Counts the visible (expanded) nodes in a projected tree.
    private static func treeVisibleCount(_ roots: [TreeDisplayNode], _ expanded: Set<String>) -> Int {
        var count = 0
        func walk(_ nodes: [TreeDisplayNode]) {
            guard !nodes.isEmpty else { return }   // base case: no children to count
            for node in nodes {
                count += 1
                if expanded.contains(node.id) { walk(node.children) }
            }
        }
        walk(roots)
        return count
    }
}
