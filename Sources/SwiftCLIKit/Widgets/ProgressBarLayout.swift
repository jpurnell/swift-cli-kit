// ProgressBarLayout.swift
// SwiftCLIKit
//
// The compute-then-draw decision for a progress bar — division-safe ratio, the
// percentage label, and the zero-total fallback — factored out of
// `ProgressBar.render` so alternative renderers (SwiftGUIKit's CellRenderer)
// reproduce the exact same behavior.

import Foundation

/// The resolved content of a progress bar: either a drawable bar (ratio + label)
/// or the zero-total fallback (an optional "0%" label, no bar).
public struct ProgressBarLayout: Sendable, Equatable {

    /// What a progress bar resolves to for given inputs.
    public enum Content: Sendable, Equatable {
        /// Total was non-positive: show `label` (if any) and no bar.
        case zeroTotal(label: String?)
        /// A drawable bar with a clamped `ratio` and an optional centered `label`.
        case bar(ratio: Double, label: String?)
    }

    /// The resolved content.
    public let content: Content

    /// Resolves progress-bar content.
    /// - Parameters:
    ///   - current: The current progress value.
    ///   - total: The total value; values `<= 0` produce ``Content/zeroTotal(label:)``.
    ///   - showPercentage: Whether to include a percentage label.
    public init(current: Double, total: Double, showPercentage: Bool) {
        guard total > 0 else {
            content = .zeroTotal(label: showPercentage ? "0%" : nil)
            return
        }
        let ratio = Swift.min(Swift.max(current / total, 0.0), 1.0)
        let label: String? = showPercentage ? "\(Int(ratio * 100))%" : nil
        content = .bar(ratio: ratio, label: label)
    }
}
