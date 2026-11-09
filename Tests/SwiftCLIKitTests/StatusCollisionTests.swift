// StatusCollisionTests.swift
// SwiftCLIKit

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("StatusCollision")
struct StatusCollisionTests {

    private func rgb(_ hex: String) -> TerminalRGB {
        TerminalRGB(hex: hex) ?? TerminalRGB(r: 0, g: 0, b: 0)
    }

    private let success = "#30D158"
    private let destructive = "#FF4245"

    @Test("green foregrounds collide with success green", arguments: ["#00FF00", "#33FF33", "#00CC44"])
    func greenCollides(foreground: String) {
        #expect(StatusCollision.collides(foreground: rgb(foreground), status: rgb(success)))
    }

    @Test("white and amber do not collide with success green", arguments: ["#E6E6E3", "#FFBF00", "#FF9230"])
    func othersDoNot(foreground: String) {
        #expect(!StatusCollision.collides(foreground: rgb(foreground), status: rgb(success)))
    }

    @Test("red foreground collides with destructive")
    func redCollides() {
        #expect(StatusCollision.collides(foreground: rgb("#FF0000"), status: rgb(destructive)))
        #expect(StatusCollision.collides(foreground: rgb("#FF4245"), status: rgb(destructive)))
    }

    @Test("white does not collide with destructive")
    func whiteVsRed() {
        #expect(!StatusCollision.collides(foreground: rgb("#E6E6E3"), status: rgb(destructive)))
    }

    @Test("distance is symmetric and zero for equal colours")
    func distance() {
        let a = rgb("#00FF00")
        let b = rgb(success)
        #expect(ColorMath.oklabDistance(a, a) == 0)
        #expect(ColorMath.oklabDistance(a, b) == ColorMath.oklabDistance(b, a))
    }
}
