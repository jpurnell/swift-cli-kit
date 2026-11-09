// StatusCollision.swift
// SwiftCLIKit

import Foundation

/// Detects a default foreground so close to a status colour that colour cannot tell them apart.
public enum StatusCollision {

    /// OKLab distance (times 100) below which two colours are treated as indistinguishable.
    /// This is the normal-vision floor the colour validator uses.
    public static let distanceFloor = 15.0

    /// Whether `foreground` is too close to `status` for the status to be told apart by colour.
    /// - Parameters:
    ///   - foreground: The terminal's default foreground.
    ///   - status: A status colour such as success or destructive.
    /// - Returns: `true` when the OKLab distance times 100 is below ``distanceFloor``.
    public static func collides(foreground: TerminalRGB, status: TerminalRGB) -> Bool {
        ColorMath.oklabDistance(foreground, status) < distanceFloor
    }
}
