// QualityGateDashboardTests.swift
// QualityGateDashboard
// The capstone: one scene(checks:), rendered to both surfaces.

import Testing
import Foundation
import SwiftCLIKit
import SwiftGUIKit
@testable import QualityGateDashboard

private let sampleChecks = [
    GateCheck(name: "build", status: .passed),
    GateCheck(name: "safety", status: .passed),
    GateCheck(name: "doc-coverage", status: .warning, warnings: 2),
]

@Suite("QualityGateDashboard")
struct QualityGateDashboardTests {

    @Test("scene builds a Node tree from check results")
    func sceneBuilds() {
        let node = QualityGateDashboard.scene(checks: sampleChecks)
        // Top level is the titled Block wrapping the dashboard body.
        guard case let .block(title, _, _, _, _) = node else {
            Issue.record("expected a block at the root"); return
        }
        #expect(title == "Quality Gate")
    }

    @Test("terminal render produces displayable output containing the check names")
    func terminalRender() {
        let ansi = QualityGateDashboard.renderTerminal(checks: sampleChecks, width: 40, height: 12)
        // The ANSI carries the dashboard text. DiffRenderer cursor-moves over blank
        // cells, so words with internal spaces aren't contiguous substrings — assert
        // on space-free tokens (each still renders correctly on a real terminal).
        #expect(ansi.contains("Quality"))
        #expect(ansi.contains("Gate"))
        #expect(ansi.contains("build"))
        #expect(ansi.contains("safety"))
        #expect(ansi.contains("doc-coverage"))
        #expect(ansi.contains("passed"))     // from the gauge label "n/m passed"
    }

    @Test("all-passing vs failing changes the summary status color role")
    func statusRollup() {
        // Passing checks → success; a failing check flips the summary to destructive.
        let passing = [GateCheck(name: "build", status: .passed)]
        let failing = [GateCheck(name: "build", status: .failed, errors: 3)]
        // Render both; they must differ (the failing one carries the error count text).
        let a = QualityGateDashboard.renderTerminal(checks: passing, width: 30, height: 8)
        let b = QualityGateDashboard.renderTerminal(checks: failing, width: 30, height: 8)
        #expect(a != b)
        #expect(b.contains("3E"))    // failing row shows 3 errors
    }
}

@Suite("QualityGateDashboard — JSON ingestion")
struct QualityGateJSONTests {
    @Test("parses quality-gate --format json into GateChecks with rolled-up status")
    func parsesJSON() throws {
        let json = """
        { "results": [
            { "checkerId": "build", "status": "passed", "diagnostics": [] },
            { "checkerId": "doc-coverage", "status": "passed",
              "diagnostics": [ {"severity": "warning"}, {"severity": "note"} ] },
            { "checkerId": "recursion", "status": "failed",
              "diagnostics": [ {"severity": "error"} ] }
        ] }
        """
        let checks = try QualityGateDashboard.checks(fromJSON: Data(json.utf8))
        #expect(checks.count == 3)
        #expect(checks[0] == GateCheck(name: "build", status: .passed))
        #expect(checks[1] == GateCheck(name: "doc-coverage", status: .warning, warnings: 1))  // note ignored
        #expect(checks[2] == GateCheck(name: "recursion", status: .failed, errors: 1))
    }
}

#if canImport(SwiftUI)
import SwiftUI
import SwiftGUIKitSwiftUI

@Suite("QualityGateDashboard — SwiftUI surface")
struct QualityGateDashboardSwiftUITests {
    @Test("the same scene renders as a SwiftUI view")
    func swiftUIRender() {
        let node = QualityGateDashboard.scene(checks: sampleChecks)
        _ = SwiftUIRenderer().view(for: node)   // one scene, second surface
        #expect(Bool(true))
    }
}
#endif
