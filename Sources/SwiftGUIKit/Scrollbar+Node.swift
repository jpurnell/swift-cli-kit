// Scrollbar+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Scrollbar` widget into the semantic scene graph. The
// legacy render path is untouched.

import SwiftCLIKit

public extension Scrollbar {
    /// Projects this scrollbar into a semantic ``Node``.
    /// - Parameters:
    ///   - trackColor: The track color role (default: ``ColorRole/separator``).
    ///   - thumbColor: The thumb color role (default: ``ColorRole/accent``).
    /// - Returns: A ``Node/scrollbar(orientation:contentLength:viewportSize:offset:trackColor:thumbColor:)`` node.
    func node(trackColor: ColorRole = .separator, thumbColor: ColorRole = .accent) -> Node {
        .scrollbar(orientation: orientation, contentLength: contentLength, viewportSize: viewportSize,
                   offset: offset, trackColor: trackColor, thumbColor: thumbColor)
    }
}
