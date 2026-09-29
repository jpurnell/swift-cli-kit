// PaletteRegistry.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A registry of palette actions that supports fuzzy search.
///
/// Components register actions they expose; the command palette queries
/// the registry to present filtered, ranked results to the user.
///
/// ```swift
/// var registry = PaletteRegistry()
/// registry.register(PaletteAction(id: "file.save", label: "Save File"))
/// let results = registry.search(query: "sav")
/// ```
public struct PaletteRegistry: Sendable {
    /// The stored actions.
    private var actions: [PaletteAction]

    /// Creates an empty registry.
    public init() {
        self.actions = []
    }

    /// Registers a new action. If an action with the same ID already exists,
    /// it is replaced.
    /// - Parameter action: The action to register.
    public mutating func register(_ action: PaletteAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
        } else {
            actions.append(action)
        }
    }

    /// Removes the action with the given ID. No-op if not found.
    /// - Parameter id: The identifier of the action to remove.
    public mutating func unregister(id: String) {
        actions.removeAll { $0.id == id }
    }

    /// Returns actions matching the query, sorted by fuzzy match score (best first).
    ///
    /// An empty query returns all actions sorted alphabetically by label.
    /// - Parameter query: The search string.
    /// - Returns: Matching actions sorted by relevance.
    public func search(query: String) -> [PaletteAction] {
        if query.isEmpty {
            return actions.sorted { $0.label.lowercased() < $1.label.lowercased() }
        }

        var scored: [(action: PaletteAction, score: Int)] = []
        for action in actions {
            if let matchScore = FuzzyMatcher.score(query, against: action.label) {
                scored.append((action, matchScore))
            }
        }

        // Sort by score descending, then label ascending for stability
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.action.label.lowercased() < rhs.action.label.lowercased()
        }

        return scored.map(\.action)
    }

    /// All registered actions in insertion order.
    public var allActions: [PaletteAction] {
        actions
    }
}
