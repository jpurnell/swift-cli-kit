// BoxDrawing.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A set of box-drawing characters used to render bordered UI elements in the terminal.
public struct BoxDrawing: Sendable, Equatable, Hashable {
    /// Top-left corner character.
    public let topLeft: String
    /// Top-right corner character.
    public let topRight: String
    /// Bottom-left corner character.
    public let bottomLeft: String
    /// Bottom-right corner character.
    public let bottomRight: String
    /// Horizontal line character.
    public let horizontal: String
    /// Vertical line character.
    public let vertical: String
    /// Left T-junction character.
    public let leftTee: String
    /// Right T-junction character.
    public let rightTee: String
    /// Top T-junction character.
    public let topTee: String
    /// Bottom T-junction character.
    public let bottomTee: String
    /// Cross/intersection character.
    public let cross: String

    /// Unicode light box-drawing preset (U+250x).
    public static let unicode = BoxDrawing(
        topLeft: "\u{250C}", topRight: "\u{2510}", bottomLeft: "\u{2514}", bottomRight: "\u{2518}",
        horizontal: "\u{2500}", vertical: "\u{2502}",
        leftTee: "\u{251C}", rightTee: "\u{2524}", topTee: "\u{252C}", bottomTee: "\u{2534}", cross: "\u{253C}"
    )

    /// ASCII-only fallback preset using `+`, `-`, and `|`.
    public static let ascii = BoxDrawing(
        topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+",
        horizontal: "-", vertical: "|",
        leftTee: "+", rightTee: "+", topTee: "+", bottomTee: "+", cross: "+"
    )

    /// Draws a top border with an optional inline header, truncated to fit.
    /// - Parameter header: Text to embed in the top border.
    /// - Parameter width: Total border width in columns.
    /// - Returns: A single-line top border string.
    public func topBorder(_ header: String, width: Int) -> String {
        guard width > 0 else { return "" }
        let maxContent = width - 2 // 2 for corners
        let headerVisible = ANSIStringMetrics.visibleLength(header)
        let usedHeader: String
        if headerVisible > maxContent {
            usedHeader = ANSIStringMetrics.truncateVisible(header, to: maxContent)
        } else {
            usedHeader = header
        }
        let remaining = max(0, maxContent - ANSIStringMetrics.visibleLength(usedHeader))
        return topLeft + usedHeader + String(repeating: horizontal, count: remaining) + topRight
    }

    /// Draws a horizontal mid-border (divider) row.
    /// - Parameter width: Total border width in columns.
    /// - Returns: A single-line mid border string.
    public func midBorder(width: Int) -> String {
        guard width >= 2 else { return "" }
        return leftTee + String(repeating: horizontal, count: width - 2) + rightTee
    }

    /// Draws a bottom border row.
    /// - Parameter width: Total border width in columns.
    /// - Returns: A single-line bottom border string.
    public func bottomBorder(width: Int) -> String {
        guard width >= 2 else { return "" }
        return bottomLeft + String(repeating: horizontal, count: width - 2) + bottomRight
    }
}
