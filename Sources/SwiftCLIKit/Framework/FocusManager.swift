// FocusManager.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Manages keyboard focus across a set of named UI elements.
///
/// `FocusManager` tracks a linear focus order and supports tab/shift-tab
/// cycling, direct focus by ID, and blur.
///
/// ```swift
/// var fm = FocusManager(focusOrder: ["username", "password", "submit"])
/// fm.focused   // "username"
/// fm.focusNext()
/// fm.focused   // "password"
/// ```
public struct FocusManager: Sendable {
    /// A type alias for focus identifiers.
    public typealias FocusID = String

    /// The ordered list of focusable element IDs.
    public var focusOrder: [FocusID]

    /// The current index into ``focusOrder``, or `nil` if blurred.
    private var focusIndex: Int?

    /// The currently focused element ID, or `nil` if nothing is focused.
    public var focused: FocusID? {
        guard let index = focusIndex, focusOrder.indices.contains(index) else {
            return nil
        }
        return focusOrder[index]
    }

    /// Creates a focus manager with the given focus order.
    ///
    /// If the order is non-empty, the first element is initially focused.
    /// - Parameter focusOrder: The ordered list of focusable IDs.
    public init(focusOrder: [FocusID] = []) {
        self.focusOrder = focusOrder
        self.focusIndex = focusOrder.isEmpty ? nil : 0
    }

    /// Advances focus to the next element, wrapping around to the first.
    ///
    /// If focus is currently blurred, re-enters the ring at the first element.
    public mutating func focusNext() {
        guard !focusOrder.isEmpty else { return }
        guard let current = focusIndex else {
            focusIndex = 0
            return
        }
        focusIndex = (current + 1) % focusOrder.count
    }

    /// Moves focus to the previous element, wrapping around to the last.
    ///
    /// If focus is currently blurred, re-enters the ring at the last element.
    public mutating func focusPrevious() {
        guard !focusOrder.isEmpty else { return }
        guard let current = focusIndex else {
            focusIndex = focusOrder.count - 1
            return
        }
        focusIndex = (current - 1 + focusOrder.count) % focusOrder.count
    }

    /// Sets focus to the element with the given ID.
    ///
    /// If the ID is not in ``focusOrder``, focus is unchanged.
    /// - Parameter id: The ID of the element to focus.
    public mutating func focus(_ id: FocusID) {
        guard let index = focusOrder.firstIndex(of: id) else { return }
        focusIndex = index
    }

    /// Removes focus from all elements.
    public mutating func blur() {
        focusIndex = nil
    }

    /// Returns whether the given ID is the currently focused element.
    /// - Parameter id: The ID to check.
    /// - Returns: `true` if `id` matches ``focused``.
    public func isFocused(_ id: FocusID) -> Bool {
        focused == id
    }
}
