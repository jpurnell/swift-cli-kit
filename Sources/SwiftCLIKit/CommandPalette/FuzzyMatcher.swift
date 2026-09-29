// FuzzyMatcher.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A pure-function fuzzy string matcher for the command palette.
///
/// Scores a query against a candidate using case-insensitive subsequence
/// matching. Higher scores indicate better matches:
/// - Exact match: highest score
/// - Prefix match: high score
/// - Consecutive subsequence: medium score
/// - Scattered subsequence: low score
/// - No match: `nil`
///
/// ```swift
/// let score = FuzzyMatcher.score("sf", against: "Save File")
/// // score is non-nil — "s" matches "S", "f" matches "F"
/// ```
public enum FuzzyMatcher {

    /// Bonus points for an exact (case-insensitive) match.
    private static let exactMatchBonus: Int = 10

    /// Bonus points when the query is a prefix of the candidate.
    private static let prefixBonus: Int = 5

    /// Bonus points for each pair of consecutively matched characters.
    private static let consecutiveBonus: Int = 2

    /// Base points awarded per matched character.
    private static let perCharacterScore: Int = 1

    /// Scores a query against a candidate string.
    ///
    /// Returns `nil` if the query is not a subsequence of the candidate
    /// (case-insensitive). Returns `0` for an empty query (matches everything).
    /// Higher values indicate better matches.
    ///
    /// - Parameters:
    ///   - query: The search string typed by the user.
    ///   - candidate: The label to match against.
    /// - Returns: An integer score, or `nil` when there is no match.
    public static func score(_ query: String, against candidate: String) -> Int? {
        guard !query.isEmpty else { return 0 }

        let lowerQuery = query.lowercased()
        let lowerCandidate = candidate.lowercased()

        // Exact match check
        if lowerQuery == lowerCandidate {
            return exactMatchBonus + prefixBonus + lowerQuery.count * perCharacterScore
        }

        // Prefix check
        let isPrefix = lowerCandidate.hasPrefix(lowerQuery)

        // Subsequence matching with consecutive tracking
        var queryIndex = lowerQuery.startIndex
        var lastMatchIndex: String.Index?
        var consecutiveCount = 0
        var totalScore = 0

        for candidateIndex in lowerCandidate.indices {
            guard queryIndex < lowerQuery.endIndex else { break }

            if lowerCandidate[candidateIndex] == lowerQuery[queryIndex] {
                totalScore += perCharacterScore

                if let last = lastMatchIndex {
                    let nextAfterLast = lowerCandidate.index(after: last)
                    if nextAfterLast == candidateIndex {
                        consecutiveCount += 1
                        totalScore += consecutiveBonus
                    }
                }
                lastMatchIndex = candidateIndex
                queryIndex = lowerQuery.index(after: queryIndex)
            }
        }

        // All query characters must have been matched
        guard queryIndex == lowerQuery.endIndex else { return nil }

        if isPrefix {
            totalScore += prefixBonus
        }

        return totalScore
    }
}
