// WindowManagerTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("WindowManager — v1.9.0 Multi-Window")
struct WindowManagerTests {

    @Test("Window cells overwrite base view cells")
    func windowOverwritesBase() {
        var buffer = CellBuffer(width: 20, height: 10)
        let wm = WindowManager(windows: [
            Window(
                id: "w1",
                rect: Rect(x: 5, y: 3, width: 5, height: 3),
                render: { frame in
                    frame.writeText("#####", x: 0, y: 0)
                    frame.writeText("#####", x: 0, y: 1)
                    frame.writeText("#####", x: 0, y: 2)
                }
            ),
        ])

        wm.render(into: &buffer, baseView: { frame in
            // Fill base with dots
            for y in 0..<10 {
                frame.writeText(String(repeating: ".", count: 20), x: 0, y: y)
            }
        })

        // Base cell outside window
        #expect(buffer[0, 0].character == ".")
        // Window cell inside window
        #expect(buffer[5, 3].character == "#")
        #expect(buffer[9, 5].character == "#")
        // Base cell below window
        #expect(buffer[0, 9].character == ".")
    }

    @Test("Higher Z-index renders on top of lower Z-index")
    func zOrderRendering() {
        var buffer = CellBuffer(width: 20, height: 10)
        let wm = WindowManager(windows: [
            Window(
                id: "bottom",
                rect: Rect(x: 2, y: 2, width: 6, height: 4),
                zIndex: 0,
                render: { frame in
                    for y in 0..<4 {
                        frame.writeText("BBBBBB", x: 0, y: y)
                    }
                }
            ),
            Window(
                id: "top",
                rect: Rect(x: 4, y: 3, width: 6, height: 4),
                zIndex: 1,
                render: { frame in
                    for y in 0..<4 {
                        frame.writeText("TTTTTT", x: 0, y: y)
                    }
                }
            ),
        ])

        wm.render(into: &buffer, baseView: { frame in
            for y in 0..<10 {
                frame.writeText(String(repeating: ".", count: 20), x: 0, y: y)
            }
        })

        // Overlap area: top window should win
        #expect(buffer[5, 4].character == "T")
        // Bottom window non-overlap area
        #expect(buffer[2, 2].character == "B")
        // Base area
        #expect(buffer[0, 0].character == ".")
    }

    @Test("Removed window is no longer rendered")
    func removeWindow() {
        var wm = WindowManager(windows: [
            Window(
                id: "temp",
                rect: Rect(x: 0, y: 0, width: 5, height: 3),
                render: { frame in
                    frame.writeText("XXXXX", x: 0, y: 0)
                }
            ),
        ])
        wm.remove(id: "temp")

        var buffer = CellBuffer(width: 20, height: 10)
        wm.render(into: &buffer, baseView: { frame in
            for y in 0..<10 {
                frame.writeText(String(repeating: ".", count: 20), x: 0, y: y)
            }
        })

        // Window was removed; base should be untouched
        #expect(buffer[0, 0].character == ".")
        #expect(wm.windows.isEmpty)
    }

    @Test("bringToFront changes Z-order so window renders on top")
    func bringToFront() {
        var wm = WindowManager(windows: [
            Window(
                id: "A",
                rect: Rect(x: 0, y: 0, width: 5, height: 3),
                zIndex: 0,
                render: { frame in
                    frame.writeText("AAAAA", x: 0, y: 0)
                }
            ),
            Window(
                id: "B",
                rect: Rect(x: 0, y: 0, width: 5, height: 3),
                zIndex: 1,
                render: { frame in
                    frame.writeText("BBBBB", x: 0, y: 0)
                }
            ),
        ])

        // Bring A to front (should now have higher z than B)
        wm.bringToFront(id: "A")

        var buffer = CellBuffer(width: 20, height: 10)
        wm.render(into: &buffer, baseView: { _ in })

        // A should be on top now
        #expect(buffer[0, 0].character == "A")
    }

    @Test("Modal window dims background cells")
    func modalDimsBackground() {
        var buffer = CellBuffer(width: 20, height: 10)
        let wm = WindowManager(windows: [
            Window(
                id: "modal",
                rect: Rect(x: 5, y: 3, width: 5, height: 3),
                zIndex: 10,
                render: { frame in
                    frame.writeText("MODAL", x: 0, y: 0)
                },
                isModal: true
            ),
        ])

        wm.render(into: &buffer, baseView: { frame in
            for y in 0..<10 {
                frame.writeText(String(repeating: ".", count: 20), x: 0, y: y)
            }
        })

        // Background cells should have .dim attribute
        #expect(buffer[0, 0].attributes.contains(.dim))
        // Modal window cells should be written by the window render
        #expect(buffer[5, 3].character == "M")
    }
}
