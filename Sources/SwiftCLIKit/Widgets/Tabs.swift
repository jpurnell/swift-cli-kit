// Tabs.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A tab bar widget that renders a row of selectable tabs with an active indicator.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let tabs = Tabs(titles: ["Home", "Settings", "About"], activeIndex: 1)
/// tabs.render(into: &frame)
/// ```
public struct Tabs: Sendable {
    /// The tab titles.
    public var titles: [String]
    /// The index of the active tab.
    public var activeIndex: Int
    /// The style for the active tab.
    public var activeStyle: CellStyle
    /// The style for inactive tabs.
    public var inactiveStyle: CellStyle
    /// The separator string between tabs.
    public var separator: String
    /// An optional underline character drawn below the active tab.
    public var underline: Character?

    /// Creates a tabs widget.
    /// - Parameters:
    ///   - titles: The tab titles.
    ///   - activeIndex: The active tab index (default: 0).
    ///   - activeStyle: Style for the active tab (default: bold).
    ///   - inactiveStyle: Style for inactive tabs (default: default style).
    ///   - separator: Separator between tabs (default: " | ").
    ///   - underline: Optional underline character for the active tab.
    public init(
        titles: [String],
        activeIndex: Int = 0,
        activeStyle: CellStyle = CellStyle(attributes: [.bold]),
        inactiveStyle: CellStyle = CellStyle(),
        separator: String = " | ",
        underline: Character? = nil
    ) {
        self.titles = titles
        self.activeIndex = activeIndex
        self.activeStyle = activeStyle
        self.inactiveStyle = inactiveStyle
        self.separator = separator
        self.underline = underline
    }

    /// Renders this tab bar into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        // Drawing is owned by TabsRenderer so alternative renderers cannot drift.
        TabsRenderer.draw(
            into: &frame,
            titles: titles,
            activeIndex: activeIndex,
            separator: separator,
            underline: underline,
            activeStyle: activeStyle,
            inactiveStyle: inactiveStyle
        )
    }
}

// MARK: - AccessibleWidget

extension Tabs: AccessibleWidget {
    /// An accessibility label describing the tab bar, including the active tab title and position.
    public var accessibilityLabel: AccessibilityLabel {
        let active = activeIndex < titles.count ? titles[activeIndex] : ""
        return AccessibilityLabel(
            role: .tab,
            label: "Tabs: \(active) (\(activeIndex + 1) of \(titles.count))",
            hint: "Left/Right to switch tabs",
            childCount: titles.count
        )
    }
}
