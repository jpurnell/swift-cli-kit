// Layout.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Layout utilities for splitting terminal areas into sub-regions.
///
/// The `Layout` enum provides constraint-based splitting similar to ratatui's layout system.
///
/// ```swift
/// let chunks = Layout.split(
///     area: Rect(x: 0, y: 0, width: 100, height: 24),
///     direction: .horizontal,
///     constraints: [.fixed(20), .percentage(50), .fixed(30)]
/// )
/// ```
public enum Layout {
    /// The direction in which to split an area.
    public enum Direction: Sendable {
        /// Split left to right.
        case horizontal
        /// Split top to bottom.
        case vertical
    }

    /// A constraint that controls how space is allocated during a layout split.
    public enum Constraint: Sendable, Equatable, Hashable {
        /// An exact number of columns or rows.
        case fixed(Int)
        /// A percentage (0-100) of available space.
        case percentage(UInt16)
        /// A minimum size.
        case min(Int)
        /// A maximum size.
        case max(Int)
        /// A proportional share (numerator, denominator).
        case ratio(Int, Int)
    }

    /// Splits the given area according to direction and constraints.
    /// - Parameters:
    ///   - area: The rectangle to subdivide.
    ///   - direction: Horizontal or vertical split.
    ///   - constraints: How to allocate space among the resulting rectangles.
    /// - Returns: An array of sub-rectangles, one per constraint.
    public static func split(area: Rect, direction: Direction, constraints: [Constraint]) -> [Rect] {
        guard !constraints.isEmpty else { return [] }

        let total: Int
        switch direction {
        case .horizontal: total = area.width
        case .vertical: total = area.height
        }

        // Pass 1: resolve each constraint to a desired size; mark flexible ones.
        var sizes = [Int](repeating: 0, count: constraints.count)
        var isFlexible = [Bool](repeating: false, count: constraints.count)
        var usedByFixed = 0

        for (i, constraint) in constraints.enumerated() {
            switch constraint {
            case .fixed(let n):
                sizes[i] = n
                usedByFixed += n
            case .percentage(let p):
                let s = total * Int(p) / 100
                sizes[i] = s
                usedByFixed += s
            case .ratio(let n, let d):
                guard d != 0 else {
                    sizes[i] = 0
                    continue
                }
                let s = total * n / d
                sizes[i] = s
                usedByFixed += s
            case .min:
                isFlexible[i] = true
            case .max:
                isFlexible[i] = true
            }
        }

        // Pass 2: distribute remaining space to flexible constraints.
        let flexCount = isFlexible.filter { $0 }.count
        let remaining = Swift.max(0, total - usedByFixed)

        if flexCount > 0 {
            let share = remaining / flexCount
            var extra = remaining - share * flexCount
            for i in 0..<constraints.count {
                guard isFlexible[i] else { continue }
                var s = share + (extra > 0 ? 1 : 0)
                if extra > 0 { extra -= 1 }
                switch constraints[i] {
                case .min(let m):
                    s = Swift.max(s, m)
                case .max(let m):
                    s = Swift.min(s, m)
                default:
                    break
                }
                sizes[i] = s
            }
        }

        // Clamp: no rect extends past area bounds.
        var offset = 0
        var rects = [Rect]()
        rects.reserveCapacity(constraints.count)

        for i in 0..<constraints.count {
            let available = Swift.max(0, total - offset)
            let clamped: Int
            switch constraints[i] {
            case .fixed:
                // Fixed constraints get their full size or 0 if not enough space.
                clamped = sizes[i] <= available ? sizes[i] : 0
            default:
                clamped = Swift.min(sizes[i], available)
            }
            switch direction {
            case .horizontal:
                rects.append(Rect(x: area.x + offset, y: area.y, width: clamped, height: area.height))
            case .vertical:
                rects.append(Rect(x: area.x, y: area.y + offset, width: area.width, height: clamped))
            }
            offset += clamped
        }

        return rects
    }
}
