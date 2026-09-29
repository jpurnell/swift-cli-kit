// GaugeNodeTests.swift
// SwiftGUIKit
// Phase 0 — §1c: Gauge → Node structural tests (RED first).

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Gauge.node")
struct GaugeNodeTests {

    @Test("node() carries semantic intent with default fill/track roles")
    func nodeDefaults() {
        let node = Gauge(ratio: 0.5, label: "50%").node()
        #expect(node == .gauge(ratio: 0.5, label: "50%", fill: .accent, track: .separator))
    }

    @Test("node() passes the raw ratio through — clamping happens at render, as in legacy")
    func nodePassesRawRatio() {
        let node = Gauge(ratio: 1.5).node()
        #expect(node == .gauge(ratio: 1.5, label: nil, fill: .accent, track: .separator))
    }

    @Test("node() honors explicitly chosen semantic roles")
    func nodeCustomRoles() {
        let node = Gauge(ratio: 0.25).node(fill: .success, track: .secondaryLabel)
        #expect(node == .gauge(ratio: 0.25, label: nil, fill: .success, track: .secondaryLabel))
    }
}
