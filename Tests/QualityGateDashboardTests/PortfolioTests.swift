// PortfolioTests.swift
// QualityGateDashboard
// Portfolio parse + scene rendering (from `quality-gate dashboard --output-format json`).

import Testing
import Foundation
import SwiftCLIKit
import SwiftGUIKit
@testable import QualityGateDashboard

private let sampleJSON = """
{ "totalProjects": 2, "passingProjects": 1, "failingProjects": 1,
  "worstCheckers": ["logging", "safety"],
  "projects": [
    {"projectID": "Alpha", "passRate": 0.9, "runCount": 10, "latestPassed": true,
     "totalOverrides": 2, "checkerPassRates": {"build": 1.0, "safety": 0.8}},
    {"projectID": "Beta", "passRate": 0.5, "runCount": 20, "latestPassed": false,
     "totalOverrides": 5, "checkerPassRates": {"build": 0.9, "logging": 0.4}}
  ] }
"""

@Suite("PortfolioDashboard")
struct PortfolioTests {

    @Test("parses portfolio JSON incl. derived totals")
    func parse() throws {
        let portfolio = try PortfolioDashboard.portfolio(fromJSON: Data(sampleJSON.utf8))
        #expect(portfolio.totalProjects == 2)
        #expect(portfolio.passingProjects == 1)
        #expect(portfolio.failingProjects == 1)
        #expect(portfolio.projects.count == 2)
        #expect(portfolio.totalRuns == 30)
        #expect(portfolio.totalOverrides == 7)
        #expect(portfolio.worstCheckers == ["logging", "safety"])
    }

    private func lineIndex(_ text: String, containing needle: String) -> Int? {
        text.lines.firstIndex { $0.contains(needle) }
    }

    @Test("portfolio scene: header, counts, and projects sorted by pass rate")
    func portfolioScene() throws {
        let portfolio = try PortfolioDashboard.portfolio(fromJSON: Data(sampleJSON.utf8))
        let text = QualityGateDashboard.renderPlainText(
            node: PortfolioDashboard.portfolioScene(portfolio), width: 52, height: 10)
        #expect(text.contains("IJS Portfolio Dashboard"))
        #expect(text.contains("2 active | 1 passing | 1 failing"))
        #expect(text.contains("Alpha"))
        #expect(text.contains("Beta"))
        // Alpha (0.9) sorts above Beta (0.5).
        let alpha = try #require(lineIndex(text, containing: "Alpha"))
        let beta = try #require(lineIndex(text, containing: "Beta"))
        #expect(alpha < beta)
    }

    @Test("project scene lists checkers worst-first")
    func projectScene() throws {
        let portfolio = try PortfolioDashboard.portfolio(fromJSON: Data(sampleJSON.utf8))
        let beta = try #require(portfolio.projects.first { $0.projectID == "Beta" })
        let text = QualityGateDashboard.renderPlainText(
            node: PortfolioDashboard.projectScene(beta), width: 52, height: 8)
        #expect(text.contains("Project: Beta"))
        #expect(text.contains("logging"))
        #expect(text.contains("build"))
        // logging (0.4) is worst, sorts above build (0.9).
        let logging = try #require(lineIndex(text, containing: "logging"))
        let build = try #require(lineIndex(text, containing: "build"))
        #expect(logging < build)
    }
}
