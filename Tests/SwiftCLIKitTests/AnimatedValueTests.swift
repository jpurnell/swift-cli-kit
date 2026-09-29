// AnimatedValueTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("AnimatedValue")
struct AnimatedValueTests {

    @Test("Double interpolation at midpoint: from 0 to 100 yields 50")
    func doubleMidpoint() {
        let start = ContinuousClock.now
        var animated = AnimatedValue(
            from: 0.0,
            to: 100.0,
            animation: Animation(duration: .seconds(2), easing: .linear)
        )
        animated.start(at: start)
        let midpoint = start + .seconds(1)
        let value = animated.value(at: midpoint)
        #expect(abs(value - 50.0) < 0.1)
    }

    @Test("At start returns from value, past end returns to value")
    func boundaries() {
        let start = ContinuousClock.now
        var animated = AnimatedValue(
            from: 0.0,
            to: 100.0,
            animation: Animation(duration: .seconds(1), easing: .linear)
        )
        animated.start(at: start)
        #expect(abs(animated.value(at: start) - 0.0) < 1e-6)
        let pastEnd = start + .seconds(5)
        #expect(abs(animated.value(at: pastEnd) - 100.0) < 1e-6)
    }

    @Test("Int interpolation at midpoint: from 0 to 10 yields 5")
    func intMidpoint() {
        let start = ContinuousClock.now
        var animated = AnimatedValue(
            from: 0,
            to: 10,
            animation: Animation(duration: .seconds(2), easing: .linear)
        )
        animated.start(at: start)
        let midpoint = start + .seconds(1)
        let value = animated.value(at: midpoint)
        #expect(value == 5)
    }
}
