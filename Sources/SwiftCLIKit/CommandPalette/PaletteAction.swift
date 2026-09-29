// PaletteAction.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// An action that can appear in the command palette.
///
/// Each action has a unique identifier, a human-readable label, and optional
/// metadata like a key binding hint and category for grouping.
///
/// ```swift
/// let action = PaletteAction(
///     id: "file.save",
///     label: "Save File",
///     keyBinding: "Ctrl+S",
///     category: "File"
/// )
/// ```
public struct PaletteAction: Sendable, Identifiable, Equatable {
    /// A unique identifier for this action.
    public var id: String

    /// The human-readable label displayed in the palette.
    public var label: String

    /// An optional key binding hint displayed alongside the label.
    public var keyBinding: String?

    /// An optional category for grouping related actions.
    public var category: String?

    /// Creates a new palette action.
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - label: Display label.
    ///   - keyBinding: Optional key binding hint.
    ///   - category: Optional grouping category.
    public init(
        id: String,
        label: String,
        keyBinding: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.label = label
        self.keyBinding = keyBinding
        self.category = category
    }
}
