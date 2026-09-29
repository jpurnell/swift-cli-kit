// PerfTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Performance Overlay")
struct PerfTests {

    @Test("PerfTracker beginFrame/endFrame calculates FPS")
    func trackerCalculatesFPS() {
        var tracker = PerfTracker()

        // Record several frames with known durations
        for _ in 0..<10 {
            tracker.beginFrame()
            // Simulate ~16ms frame by recording manually
            tracker.endFrame()
        }

        // Frames should have been recorded
        #expect(tracker.totalFrameCount == 10)
        // FPS should be positive (exact value depends on timing)
        #expect(tracker.currentFPS >= 0)
    }

    @Test("PerfTracker recordUpdateDuration stores value")
    func trackerRecordsUpdateDuration() {
        var tracker = PerfTracker()
        let duration: Duration = .milliseconds(2)
        tracker.recordUpdateDuration(duration)
        #expect(tracker.lastUpdateDuration == duration)
    }

    @Test("PerfTracker recordViewDuration stores value")
    func trackerRecordsViewDuration() {
        var tracker = PerfTracker()
        let duration: Duration = .milliseconds(3)
        tracker.recordViewDuration(duration)
        #expect(tracker.lastViewDuration == duration)
    }

    @Test("PerfTracker recordDiffCellCount stores value")
    func trackerRecordsDiffCellCount() {
        var tracker = PerfTracker()
        tracker.recordDiffCellCount(500)
        #expect(tracker.lastDiffCellCount == 500)
    }

    @Test("PerfTracker zero frames returns zero FPS")
    func zeroFramesZeroFPS() {
        let tracker = PerfTracker()
        #expect(abs(tracker.currentFPS - 0.0) < 1e-6)
        #expect(tracker.averageFrameTime == .zero)
    }

    @Test("BottleneckDetector duration exceeds threshold produces warning")
    func bottleneckExceedsThreshold() {
        var tracker = PerfTracker()
        tracker.recordUpdateDuration(.milliseconds(5))
        tracker.recordViewDuration(.milliseconds(10))

        let detector = BottleneckDetector(
            updateThreshold: .milliseconds(1),
            viewThreshold: .milliseconds(5),
            frameThreshold: .milliseconds(16)
        )

        let warnings = detector.check(tracker: tracker)
        #expect(warnings.contains { $0.kind == .slowUpdate })
        #expect(warnings.contains { $0.kind == .slowView })
    }

    @Test("BottleneckDetector duration below threshold produces no warning")
    func bottleneckBelowThreshold() {
        var tracker = PerfTracker()
        tracker.recordUpdateDuration(.microseconds(100))
        tracker.recordViewDuration(.milliseconds(1))

        let detector = BottleneckDetector(
            updateThreshold: .milliseconds(1),
            viewThreshold: .milliseconds(5),
            frameThreshold: .milliseconds(16)
        )

        let warnings = detector.check(tracker: tracker)
        // No update or view warnings expected
        let updateWarnings = warnings.filter { $0.kind == .slowUpdate }
        let viewWarnings = warnings.filter { $0.kind == .slowView }
        #expect(updateWarnings.isEmpty)
        #expect(viewWarnings.isEmpty)
    }

    @Test("PerfOverlay render produces non-empty cells when visible")
    func overlayRendersWhenVisible() {
        var overlay = PerfOverlay(position: .topRight)
        overlay.isVisible = true
        overlay.tracker.beginFrame()
        overlay.tracker.endFrame()
        overlay.tracker.recordDiffCellCount(42)

        let buf = CellBuffer(width: 80, height: 24)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: 80, height: 24))
        overlay.render(into: &frame)

        let result = frame.cellBuffer
        var nonEmptyCount = 0
        for y in 0..<24 {
            for x in 0..<80 {
                if result[x, y] != .empty {
                    nonEmptyCount += 1
                }
            }
        }
        #expect(nonEmptyCount > 0, "Visible overlay should render non-empty cells")
    }

    @Test("PerfOverlay not visible writes no cells")
    func overlayInvisibleWritesNothing() {
        var overlay = PerfOverlay(position: .topRight)
        overlay.isVisible = false

        let buf = CellBuffer(width: 80, height: 24)
        var frame = Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: 80, height: 24))
        overlay.render(into: &frame)

        let result = frame.cellBuffer
        var nonEmptyCount = 0
        for y in 0..<24 {
            for x in 0..<80 {
                if result[x, y] != .empty {
                    nonEmptyCount += 1
                }
            }
        }
        #expect(nonEmptyCount == 0, "Invisible overlay should not write any cells")
    }
}
