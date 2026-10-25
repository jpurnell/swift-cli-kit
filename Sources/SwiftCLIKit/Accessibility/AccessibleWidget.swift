// AccessibleWidget.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Protocol for widgets that expose accessibility metadata.
///
/// Conforming widgets provide a computed ``accessibilityLabel`` that describes
/// their current state for screen reader announcement.
public protocol AccessibleWidget {
    /// An accessibility label describing the widget's current state.
    var accessibilityLabel: AccessibilityLabel { get }
}
