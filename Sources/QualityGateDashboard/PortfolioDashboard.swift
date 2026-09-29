// PortfolioDashboard.swift
// QualityGateDashboard
//
// Renders the IJS Portfolio Dashboard (the real `quality-gate dashboard`) as a
// SwiftGUIKit scene, from `quality-gate dashboard --output-format json`. Two
// scenes: the portfolio overview (a sortable projects Table) and a per-project
// detail (per-checker pass rates). Both render to terminal and native SwiftUI.

import Foundation
import SwiftCLIKit
import SwiftGUIKit

/// Renders the IJS Portfolio Dashboard as SwiftGUIKit scenes.
///
/// Parses `quality-gate dashboard --output-format json` into a ``Portfolio`` and
/// builds two scenes from it — a portfolio overview (a sortable projects table)
/// and a per-project detail (per-checker pass rates) — each of which renders to
/// both the terminal and native SwiftUI.
public enum PortfolioDashboard {

    /// Parses `quality-gate dashboard --output-format json` into a ``Portfolio``.
    public static func portfolio(fromJSON data: Data) throws -> Portfolio {
        try JSONDecoder().decode(Portfolio.self, from: QualityGateDashboard.firstJSONObject(in: data))
    }

    private static func percent(_ rate: Double) -> String { "\(Int((rate * 100).rounded()))%" }

    /// The portfolio overview scene: summary counts, a derived pulse line, and a
    /// projects table sorted by pass rate (rows selectable, id "portfolio").
    public static func portfolioScene(_ portfolio: Portfolio) -> Node {
        let sorted = portfolio.projects.sorted { $0.passRate > $1.passRate }
        let summaryColor: ColorRole = portfolio.failingProjects > 0 ? .warning : .success
        let summary = "\(portfolio.totalProjects) active | \(portfolio.passingProjects) passing | \(portfolio.failingProjects) failing"
        let worst = portfolio.worstCheckers.prefix(3).joined(separator: ", ")
        let pulse = "\(portfolio.totalRuns) runs · \(portfolio.totalOverrides) overrides · worst: \(worst)"

        let headers = ["Project", "", "Pass", "Runs"]
        let rows = sorted.map { project in
            [project.projectID, project.latestPassed ? "✓" : "✗", percent(project.passRate), "\(project.runCount)"]
        }
        let widths: [Layout.Constraint] = [.fixed(34), .fixed(3), .fixed(7), .fixed(7)]
        let table = Node.table(headers: headers, widths: widths, cells: rows,
                               selectedRow: nil, scrollOffset: 0,
                               sort: TableSort(column: 2, ascending: false),
                               headerColor: .label, rowColor: .label, id: "portfolio")

        return Block(title: "IJS Portfolio Dashboard", borders: .all).node(child:
            .vstack(spacing: .s, [
                StackChild(Paragraph(text: summary, wrap: false).node(color: summaryColor), size: .fit),
                StackChild(Paragraph(text: pulse, wrap: false).node(color: .secondaryLabel), size: .fit),
                StackChild(table, size: .flex(1)),
            ]))
    }

    /// A per-project detail scene: pass rate / runs / overrides summary and a
    /// per-checker table sorted worst-first.
    public static func projectScene(_ project: Portfolio.Project) -> Node {
        let summaryColor: ColorRole = project.latestPassed ? .success : .destructive
        let summary = "\(percent(project.passRate)) pass · \(project.runCount) runs · \(project.totalOverrides) overrides"

        let checkers = project.checkerPassRates.sorted { $0.value < $1.value }   // worst first
        let headers = ["Checker", "Pass"]
        let rows = checkers.map { [$0.key, percent($0.value)] }
        let widths: [Layout.Constraint] = [.fixed(40), .fixed(7)]
        let table = Node.table(headers: headers, widths: widths, cells: rows,
                               selectedRow: nil, scrollOffset: 0,
                               sort: TableSort(column: 1, ascending: true),
                               headerColor: .label, rowColor: .label, id: "project-checkers")

        return Block(title: "Project: \(project.projectID)", borders: .all).node(child:
            .vstack(spacing: .s, [
                StackChild(Paragraph(text: summary, wrap: false).node(color: summaryColor), size: .fit),
                StackChild(table, size: .flex(1)),
            ]))
    }
}
