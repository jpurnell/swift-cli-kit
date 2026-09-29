// CommandPalette.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A searchable command palette overlay, similar to VS Code's Ctrl+P.
///
/// The palette holds a registry of actions, a current query, and selection
/// state. It renders as a floating input field with filtered results below.
///
/// ```swift
/// var palette = CommandPalette()
/// palette.registry.register(PaletteAction(id: "save", label: "Save File"))
/// palette.show()
/// palette.updateQuery("sav")
/// // palette.results contains the matched action
/// ```
public struct CommandPalette: Sendable {
    /// The action registry backing this palette.
    public var registry: PaletteRegistry

    /// The current search query.
    public var query: String

    /// The index of the currently selected result.
    public var selectedIndex: Int

    /// Whether the palette overlay is visible.
    public var isVisible: Bool

    /// The filtered results for the current query.
    public var results: [PaletteAction]

    /// Creates a new command palette.
    /// - Parameter registry: An initial registry of actions (default: empty).
    public init(registry: PaletteRegistry = PaletteRegistry()) {
        self.registry = registry
        self.query = ""
        self.selectedIndex = 0
        self.isVisible = false
        self.results = registry.search(query: "")
    }

    /// Shows the palette, resetting the query and selection.
    public mutating func show() {
        isVisible = true
        query = ""
        selectedIndex = 0
        results = registry.search(query: "")
    }

    /// Hides the palette.
    public mutating func hide() {
        isVisible = false
    }

    /// Updates the search query and refreshes filtered results.
    /// - Parameter query: The new search string.
    public mutating func updateQuery(_ query: String) {
        self.query = query
        results = registry.search(query: query)
        selectedIndex = 0
    }

    /// Moves the selection to the next result, wrapping to the top.
    public mutating func selectNext() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % results.count
    }

    /// Moves the selection to the previous result, wrapping to the bottom.
    public mutating func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + results.count) % results.count
    }

    /// The currently selected action, or `nil` when results are empty.
    public var selectedAction: PaletteAction? {
        guard !results.isEmpty,
              selectedIndex >= 0,
              selectedIndex < results.count else {
            return nil
        }
        return results[selectedIndex]
    }

    // MARK: - Rendering

    /// Width of the palette overlay in columns.
    private static let paletteWidth: Int = 40

    /// Maximum number of result rows displayed.
    private static let maxVisibleResults: Int = 10

    /// Renders the palette into the given frame.
    ///
    /// When `isVisible` is false, this is a no-op. When visible, the palette
    /// renders a search input field at the top with filtered results below,
    /// highlighting the selected row.
    ///
    /// - Parameter frame: The rendering surface to draw into.
    public func render(into frame: inout Frame) {
        guard isVisible else { return }

        let width = min(Self.paletteWidth, frame.rect.width)
        guard width > 2, frame.rect.height > 2 else { return }

        let visibleCount = min(results.count, Self.maxVisibleResults)
        let height = min(visibleCount + 3, frame.rect.height) // header + input + results + border
        let originX = max((frame.rect.width - width) / 2, 0)
        let originY = 1

        // Draw border background
        let borderCell = Cell(character: " ", bg: .ansi8(.blue))
        for row in 0..<height {
            for col in 0..<width {
                frame.setCell(x: originX + col, y: originY + row, cell: borderCell)
            }
        }

        // Draw query input line
        let inputPrefix = "> "
        let inputLine = inputPrefix + query
        let truncatedInput = String(inputLine.prefix(width - 2))
        frame.writeText(
            truncatedInput,
            x: originX + 1,
            y: originY + 1,
            fg: .ansi8(.white),
            bg: .ansi8(.blue)
        )

        // Draw results
        for (index, action) in results.prefix(Self.maxVisibleResults).enumerated() {
            let rowY = originY + 2 + index
            guard rowY < originY + height else { break }

            let isSelected = index == selectedIndex
            let rowBg: Color = isSelected ? .ansi8(.cyan) : .ansi8(.blue)
            let rowFg: Color = isSelected ? .ansi8(.black) : .ansi8(.white)

            let label = String(action.label.prefix(width - 2))
            frame.writeText(
                label,
                x: originX + 1,
                y: rowY,
                fg: rowFg,
                bg: rowBg
            )
        }
    }
}
