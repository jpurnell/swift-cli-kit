// AnimationTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Animation")
struct AnimationTests {

    @Test("Not started: progress returns 0 and isRunning is false")
    func notStarted() {
        let anim = Animation(duration: .seconds(1), easing: .linear)
        let now = ContinuousClock.now
        #expect(abs(anim.progress(at: now) - 0.0) < 1e-6)
        #expect(anim.isRunning == false)
    }

    @Test("At midpoint: linear progress is approximately 0.5")
    func midpointProgress() {
        let start = ContinuousClock.now
        var anim = Animation(duration: .seconds(2), easing: .linear)
        anim.start(at: start)
        let midpoint = start + .seconds(1)
        let progress = anim.progress(at: midpoint)
        #expect(abs(progress - 0.5) < 0.001)
    }

    @Test("After duration: progress is 1.0")
    func completedProgress() {
        let start = ContinuousClock.now
        var anim = Animation(duration: .seconds(1), easing: .linear)
        anim.start(at: start)
        let end = start + .seconds(2)
        let progress = anim.progress(at: end)
        #expect(abs(progress - 1.0) < 1e-6)
    }

    @Test("Zero duration: immediately complete with progress 1.0")
    func zeroDuration() {
        let start = ContinuousClock.now
        var anim = Animation(duration: .zero, easing: .linear)
        anim.start(at: start)
        let progress = anim.progress(at: start)
        #expect(abs(progress - 1.0) < 1e-6)
    }

    @Test("Easing is applied to progress")
    func easingApplied() {
        let start = ContinuousClock.now
        var anim = Animation(duration: .seconds(2), easing: .easeIn)
        anim.start(at: start)
        let midpoint = start + .seconds(1)
        let progress = anim.progress(at: midpoint)
        // easeIn at 0.5 should be less than 0.5
        #expect(progress < 0.5)
        #expect(progress > 0.0)
    }

    @Test("With delay: progress stays 0 during delay period")
    func delayedStart() {
        let start = ContinuousClock.now
        var anim = Animation(duration: .seconds(1), easing: .linear, delay: .seconds(1))
        anim.start(at: start)
        // During the delay
        let duringDelay = start + .milliseconds(500)
        #expect(abs(anim.progress(at: duringDelay) - 0.0) < 1e-6)
        // After delay, at midpoint of animation
        let afterDelay = start + .milliseconds(1500)
        let progress = anim.progress(at: afterDelay)
        #expect(abs(progress - 0.5) < 0.001)
    }
}
