// AccessibilityLabelTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
@testable import SwiftCLIKit

@Suite("AccessibilityLabel")
struct AccessibilityLabelTests {

    @Test("Minimal verbosity includes only role and label")
    func formattedMinimal() {
        let label = AccessibilityLabel(
            role: .gauge,
            label: "CPU",
            value: "75%",
            hint: "Shows current usage",
            childCount: 3
        )
        let result = label.formatted(verbosity: .minimal)
        #expect(result == "gauge: CPU")
    }

    @Test("Standard verbosity includes role, label, and value")
    func formattedStandard() {
        let label = AccessibilityLabel(
            role: .gauge,
            label: "CPU",
            value: "75%",
            hint: "Shows current usage",
            childCount: 3
        )
        let result = label.formatted(verbosity: .standard)
        #expect(result == "gauge: CPU. 75%")
    }

    @Test("Verbose includes role, label, value, hint, and child count")
    func formattedVerbose() {
        let label = AccessibilityLabel(
            role: .gauge,
            label: "CPU",
            value: "75%",
            hint: "Shows current usage",
            childCount: 3
        )
        let result = label.formatted(verbosity: .verbose)
        #expect(result == "gauge: CPU. 75%. Shows current usage. 3 items")
    }

    @Test("Two identical labels are equal")
    func equalityCheck() {
        let a = AccessibilityLabel(role: .list, label: "Items", value: "5", childCount: 5)
        let b = AccessibilityLabel(role: .list, label: "Items", value: "5", childCount: 5)
        #expect(a == b)
    }

    @Test("Nil fields format without crashing")
    func nilFields() {
        let label = AccessibilityLabel(role: .button, label: "OK")
        #expect(label.formatted(verbosity: .minimal) == "button: OK")
        #expect(label.formatted(verbosity: .standard) == "button: OK")
        #expect(label.formatted(verbosity: .verbose) == "button: OK")
    }

    @Test("Labels with different values are not equal")
    func inequalityCheck() {
        let a = AccessibilityLabel(role: .list, label: "Items", value: "5")
        let b = AccessibilityLabel(role: .list, label: "Items", value: "6")
        #expect(a != b)
    }
}
