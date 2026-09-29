// Gauge+Node.swift
// SwiftGUIKit
//
// Bridges the SwiftCLIKit `Gauge` widget into the semantic scene graph. The
// legacy `Gauge.render(into:)` path is untouched; this simply offers a `node()`
// projection that carries semantic intent instead of literal styles.

import SwiftCLIKit

public extension Gauge {
    /// Projects this gauge into a semantic ``Node``.
    ///
    /// The ratio and label are passed through unchanged; fill and track are
    /// expressed as semantic color roles resolved per surface at render time.
    /// - Parameters:
    ///   - fill: The color role for the filled portion (default: ``ColorRole/accent``).
    ///   - track: The color role for the unfilled portion (default: ``ColorRole/separator``).
    /// - Returns: A ``Node/gauge(ratio:label:fill:track:)`` node.
    func node(fill: ColorRole = .accent, track: ColorRole = .separator) -> Node {
        .gauge(ratio: ratio, label: label, fill: fill, track: track)
    }
}
