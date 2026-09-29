// TransitionTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Transition")
struct TransitionTests {

    @Test("Fade enter: opacity at start is 0, at end is 1")
    func fadeEnter() {
        let start = ContinuousClock.now
        var transition = Transition(kind: .fade, duration: .seconds(1), easing: .linear)
        transition.enter(at: start)
        #expect(abs(transition.opacity(at: start) - 0.0) < 1e-6)
        let end = start + .seconds(2)
        #expect(abs(transition.opacity(at: end) - 1.0) < 1e-6)
    }

    @Test("Fade exit: opacity goes from 1 to 0")
    func fadeExit() {
        let start = ContinuousClock.now
        var transition = Transition(kind: .fade, duration: .seconds(1), easing: .linear)
        transition.exit(at: start)
        #expect(abs(transition.opacity(at: start) - 1.0) < 1e-6)
        let end = start + .seconds(2)
        #expect(abs(transition.opacity(at: end) - 0.0) < 1e-6)
    }

    @Test("SlideLeft: offset at start is negative full width, at end is 0")
    func slideLeftOffset() {
        let start = ContinuousClock.now
        var transition = Transition(kind: .slideLeft, duration: .seconds(1), easing: .linear)
        transition.enter(at: start)
        let dimension = 80
        let offsetAtStart = transition.offset(at: start, dimension: dimension)
        #expect(offsetAtStart == -dimension)
        let end = start + .seconds(2)
        let offsetAtEnd = transition.offset(at: end, dimension: dimension)
        #expect(offsetAtEnd == 0)
    }

    @Test("SlideRight: offset at start is positive full width, at end is 0")
    func slideRightOffset() {
        let start = ContinuousClock.now
        var transition = Transition(kind: .slideRight, duration: .seconds(1), easing: .linear)
        transition.enter(at: start)
        let dimension = 40
        let offsetAtStart = transition.offset(at: start, dimension: dimension)
        #expect(offsetAtStart == dimension)
        let end = start + .seconds(2)
        let offsetAtEnd = transition.offset(at: end, dimension: dimension)
        #expect(offsetAtEnd == 0)
    }
}
