// AccessibilityRole.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Semantic roles for accessible widgets, modeled after ARIA roles.
public enum AccessibilityRole: String, Sendable, CaseIterable {
    case table, list, tree, button, textField, gauge, menu, tab
    case calendar, progressBar, sparkline, scrollbar, generic
}
