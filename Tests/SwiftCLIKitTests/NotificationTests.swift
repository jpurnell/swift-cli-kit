// NotificationTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Notifications")
struct NotificationTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func extractRow(_ frame: Frame, y: Int, width: Int) -> String {
        let buf = frame.cellBuffer
        return String((0..<width).map { buf[$0, y].character })
    }

    @Test("Push toast then render shows message text")
    func pushAndRender() {
        let now = ContinuousClock.now
        var manager = NotificationManager(maxVisible: 5, position: .bottomRight)
        let toast = Toast(message: "Hello World", severity: .info, createdAt: now)
        manager.push(toast)

        var frame = makeFrame(width: 80, height: 24)
        manager.render(into: &frame, screenWidth: 80, screenHeight: 24)

        // The message should appear somewhere in the frame
        var found = false
        for y in 0..<24 {
            let row = extractRow(frame, y: y, width: 80)
            if row.contains("Hello World") {
                found = true
                break
            }
        }
        #expect(found)
    }

    @Test("Push 6 with max 5 keeps only 5")
    func maxVisibleEnforcement() {
        var manager = NotificationManager(maxVisible: 5)
        for i in 0..<6 {
            manager.push(Toast(message: "Toast \(i)"))
        }
        #expect(manager.toasts.count == 5)
        // The oldest (index 0) should have been removed
        #expect(!manager.toasts.contains(where: { $0.message == "Toast 0" }))
    }

    @Test("Dismiss by id removes correct toast")
    func dismissById() {
        var manager = NotificationManager()
        let t1 = Toast(message: "First")
        let t2 = Toast(message: "Second")
        let t3 = Toast(message: "Third")
        manager.push(t1)
        manager.push(t2)
        manager.push(t3)

        manager.dismiss(id: t2.id)
        #expect(manager.toasts.count == 2)
        #expect(!manager.toasts.contains(where: { $0.id == t2.id }))
    }

    @Test("ExpireOld removes expired toasts")
    func expireOld() {
        let now = ContinuousClock.now
        var manager = NotificationManager()
        let shortToast = Toast(
            message: "Short",
            duration: .seconds(2),
            createdAt: now
        )
        let longToast = Toast(
            message: "Long",
            duration: .seconds(10),
            createdAt: now
        )
        manager.push(shortToast)
        manager.push(longToast)

        // After 3 seconds, the short toast should expire
        manager.expireOld(now: now + .seconds(3))
        #expect(manager.toasts.count == 1)
        #expect(manager.toasts[0].message == "Long")
    }

    @Test("Severity coloring: error=red, success=green")
    func severityColors() {
        #expect(ToastSeverity.error.color == .ansi8(.red))
        #expect(ToastSeverity.success.color == .ansi8(.green))
        #expect(ToastSeverity.warning.color == .ansi8(.yellow))
        #expect(ToastSeverity.info.color == .ansi8(.cyan))
    }

    @Test("Position bottomRight renders near bottom-right corner")
    func positionBottomRight() {
        let now = ContinuousClock.now
        var manager = NotificationManager(maxVisible: 5, position: .bottomRight)
        let toast = Toast(message: "Test", severity: .success, createdAt: now)
        manager.push(toast)

        var frame = makeFrame(width: 80, height: 24)
        manager.render(into: &frame, screenWidth: 80, screenHeight: 24)

        // Toast should be at the right side (x = 80 - 40 = 40)
        // Check that right edge area has content
        let buf = frame.cellBuffer
        // The toast border should be at column 40, near bottom
        let rightEdgeCell = buf[79, 23]
        // Should not be empty (border or content)
        #expect(rightEdgeCell.character != " " || rightEdgeCell.fg != Color.default)
    }

    @Test("Empty manager renders nothing")
    func emptyRender() {
        let manager = NotificationManager()
        var frame = makeFrame(width: 80, height: 24)
        let beforeBuf = frame.cellBuffer
        manager.render(into: &frame, screenWidth: 80, screenHeight: 24)
        let afterBuf = frame.cellBuffer
        #expect(beforeBuf == afterBuf)
    }
}
