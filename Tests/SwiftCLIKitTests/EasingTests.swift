// EasingTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Easing")
struct EasingTests {

    @Test("Linear: apply(0) returns 0")
    func linearAtZero() {
        #expect(abs(Easing.linear.apply(0.0) - 0.0) < 1e-6)
    }

    @Test("Linear: apply(1) returns 1")
    func linearAtOne() {
        #expect(abs(Easing.linear.apply(1.0) - 1.0) < 1e-6)
    }

    @Test("Linear: apply(0.5) returns 0.5")
    func linearAtHalf() {
        #expect(abs(Easing.linear.apply(0.5) - 0.5) < 1e-6)
    }

    @Test("EaseIn: apply(0.5) is less than 0.5 (starts slow)")
    func easeInSlowStart() {
        let value = Easing.easeIn.apply(0.5)
        #expect(value < 0.5)
        #expect(value > 0.0)
    }

    @Test("EaseOut: apply(0.5) is greater than 0.5 (ends slow)")
    func easeOutFastStart() {
        let value = Easing.easeOut.apply(0.5)
        #expect(value > 0.5)
        #expect(value < 1.0)
    }

    @Test("EaseInOut: apply(0) returns 0 and apply(1) returns 1")
    func easeInOutEndpoints() {
        #expect(abs(Easing.easeInOut.apply(0.0) - 0.0) < 1e-6)
        #expect(abs(Easing.easeInOut.apply(1.0) - 1.0) < 1e-6)
    }

    @Test("EaseInOut: symmetric at midpoint")
    func easeInOutMidpoint() {
        let value = Easing.easeInOut.apply(0.5)
        #expect(abs(value - 0.5) < 0.001)
    }

    @Test("CubicBezier: endpoints are 0 and 1")
    func cubicBezierEndpoints() {
        let bezier = Easing.cubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0)
        #expect(abs(bezier.apply(0.0) - 0.0) < 1e-6)
        #expect(abs(bezier.apply(1.0) - 1.0) < 1e-6)
    }

    @Test("All easing functions: boundary invariant apply(0)=0 and apply(1)=1")
    func boundaryInvariant() {
        let easings: [Easing] = [
            .linear, .easeIn, .easeOut, .easeInOut,
            .cubicBezier(x1: 0.42, y1: 0.0, x2: 0.58, y2: 1.0),
            .spring(mass: 1.0, stiffness: 100.0, damping: 10.0),
            .bounce
        ]
        for easing in easings {
            #expect(abs(easing.apply(0.0) - 0.0) < 1e-6)
            #expect(abs(easing.apply(1.0) - 1.0) < 1e-6)
        }
    }

    @Test("Clamping: negative input treated as zero")
    func clampingNegative() {
        #expect(Easing.linear.apply(-0.1) == Easing.linear.apply(0.0))
        #expect(Easing.easeIn.apply(-0.5) == Easing.easeIn.apply(0.0))
    }

    @Test("Clamping: input above 1 treated as 1")
    func clampingAboveOne() {
        #expect(Easing.linear.apply(1.1) == Easing.linear.apply(1.0))
        #expect(Easing.easeOut.apply(2.0) == Easing.easeOut.apply(1.0))
    }
}
