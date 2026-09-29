// Portfolio.swift
// QualityGateDashboard
//
// The portfolio model behind the real `quality-gate dashboard` — the IJS
// Portfolio Dashboard, backed by org-judgement-corpus (historical runs) and
// org-judgement-system (governance). We consume its computed JSON
// (`quality-gate dashboard --output-format json`) rather than reimplementing the
// corpus/IJS pipeline, and render it as a SwiftGUIKit scene (terminal + SwiftUI).

import Foundation

/// A snapshot of the IJS portfolio across all projects.
public struct Portfolio: Sendable, Equatable, Decodable {
    /// The number of active projects.
    public let totalProjects: Int
    /// How many are currently passing.
    public let passingProjects: Int
    /// How many are currently failing.
    public let failingProjects: Int
    /// The per-project rows.
    public let projects: [Project]
    /// The checkers with the lowest pass rates across the portfolio.
    public let worstCheckers: [String]

    /// One project's health.
    public struct Project: Sendable, Equatable, Decodable {
        /// The project identifier.
        public let projectID: String
        /// The historical pass rate (0…1).
        public let passRate: Double
        /// The number of recorded gate runs.
        public let runCount: Int
        /// Whether the latest run passed.
        public let latestPassed: Bool
        /// The total number of overrides recorded.
        public let totalOverrides: Int
        /// Per-checker pass rates (0…1), keyed by checker id.
        public let checkerPassRates: [String: Double]

        /// Creates a project row.
        public init(projectID: String, passRate: Double, runCount: Int,
                    latestPassed: Bool, totalOverrides: Int, checkerPassRates: [String: Double]) {
            self.projectID = projectID
            self.passRate = passRate
            self.runCount = runCount
            self.latestPassed = latestPassed
            self.totalOverrides = totalOverrides
            self.checkerPassRates = checkerPassRates
        }
    }

    /// Creates a portfolio snapshot.
    public init(totalProjects: Int, passingProjects: Int, failingProjects: Int,
                projects: [Project], worstCheckers: [String]) {
        self.totalProjects = totalProjects
        self.passingProjects = passingProjects
        self.failingProjects = failingProjects
        self.projects = projects
        self.worstCheckers = worstCheckers
    }

    /// Total recorded gate runs across the portfolio (derived).
    public var totalRuns: Int { projects.reduce(0) { $0 + $1.runCount } }
    /// Total recorded overrides across the portfolio (derived).
    public var totalOverrides: Int { projects.reduce(0) { $0 + $1.totalOverrides } }
}
