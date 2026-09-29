// Rect.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// An axis-aligned rectangle in terminal grid coordinates.
///
/// `Rect` is used throughout the layout system to define regions for rendering.
/// Coordinates are zero-based, with (0, 0) at the top-left corner.
///
/// ```swift
/// let area = Rect(x: 5, y: 2, width: 40, height: 10)
/// let sub = area.intersection(Rect(x: 10, y: 0, width: 20, height: 20))
/// ```
public struct Rect: Sendable, Equatable {
    /// The left column.
    public var x: Int
    /// The top row.
    public var y: Int
    /// The width in columns.
    public var width: Int
    /// The height in rows.
    public var height: Int

    /// Creates a rectangle with the given origin and size.
    /// - Parameters:
    ///   - x: The left column (default: 0).
    ///   - y: The top row (default: 0).
    ///   - width: The width in columns (default: 0).
    ///   - height: The height in rows (default: 0).
    public init(x: Int = 0, y: Int = 0, width: Int = 0, height: Int = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The total number of cells in this rectangle.
    public var area: Int { width * height }

    /// Whether this rectangle has zero or negative area.
    public var isEmpty: Bool { area <= 0 }

    /// Returns the overlapping region between two rectangles, or `nil` if they don't overlap.
    /// - Parameter other: The rectangle to intersect with.
    /// - Returns: A ``Rect`` covering the overlap, or `nil` when the rectangles are disjoint.
    public func intersection(_ other: Rect) -> Rect? {
        let x1 = Swift.max(self.x, other.x)
        let y1 = Swift.max(self.y, other.y)
        let x2 = Swift.min(self.x + self.width, other.x + other.width)
        let y2 = Swift.min(self.y + self.height, other.y + other.height)
        guard x2 > x1, y2 > y1 else { return nil }
        return Rect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    /// Returns whether the given point is inside this rectangle.
    /// - Parameters:
    ///   - x: The column to test.
    ///   - y: The row to test.
    /// - Returns: `true` when the point falls within the rectangle's bounds.
    public func contains(x: Int, y: Int) -> Bool {
        x >= self.x && x < self.x + self.width && y >= self.y && y < self.y + self.height
    }

    /// Splits this rectangle into sub-rectangles according to the given layout constraints.
    ///
    /// This is a convenience wrapper around ``Layout/split(area:direction:constraints:)``.
    /// - Parameters:
    ///   - direction: Horizontal or vertical split.
    ///   - constraints: How to allocate space among the resulting rectangles.
    /// - Returns: An array of sub-rectangles, one per constraint.
    public func split(direction: Layout.Direction, constraints: [Layout.Constraint]) -> [Rect] {
        Layout.split(area: self, direction: direction, constraints: constraints)
    }
}
