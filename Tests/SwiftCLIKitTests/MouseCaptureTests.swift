// MouseCaptureTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-07-03.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("MouseCapture")
struct MouseCaptureTests {

    @Test("A new capture starts inactive")
    func startsInactive() {
        let capture = MouseCapture()
        #expect(capture.isActive == false)
    }

    @Test("Initializing active reflects the requested state")
    func initActive() {
        let capture = MouseCapture(active: true)
        #expect(capture.isActive == true)
    }

    @Test("activate emits the enable sequence and marks active")
    func activate() {
        var capture = MouseCapture()
        let seq = capture.activate()
        #expect(seq == MouseMode.enable)
        #expect(capture.isActive == true)
    }

    @Test("pause emits the disable sequence and marks inactive")
    func pause() {
        var capture = MouseCapture(active: true)
        let seq = capture.pause()
        #expect(seq == MouseMode.disable)
        #expect(capture.isActive == false)
    }

    @Test("toggle from inactive activates and returns the enable sequence")
    func toggleFromInactive() {
        var capture = MouseCapture(active: false)
        let seq = capture.toggle()
        #expect(seq == MouseMode.enable)
        #expect(capture.isActive == true)
    }

    @Test("toggle from active pauses and returns the disable sequence")
    func toggleFromActive() {
        var capture = MouseCapture(active: true)
        let seq = capture.toggle()
        #expect(seq == MouseMode.disable)
        #expect(capture.isActive == false)
    }
}
