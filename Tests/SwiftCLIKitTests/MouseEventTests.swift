// MouseEventTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("MouseEvent")
struct MouseEventTests {

    @Test("MouseMode.enable contains SGR enable sequences")
    func enableSequence() {
        #expect(MouseMode.enable.contains("\u{001B}[?1006h"))
    }

    @Test("MouseMode.disable contains SGR disable sequences")
    func disableSequence() {
        #expect(MouseMode.disable.contains("\u{001B}[?1006l"))
    }

    @Test("Parse left click at column 10, row 20")
    func parseLeftClick() throws {
        // SGR: <0;10;20M → bytes for "<0;10;20M"
        let bytes: [UInt8] = [0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.button == .left)
        #expect(event.column == 10)
        #expect(event.row == 20)
    }

    @Test("Parse right click at column 5, row 3")
    func parseRightClick() throws {
        // SGR: <2;5;3M
        let bytes: [UInt8] = [0x3C, 0x32, 0x3B, 0x35, 0x3B, 0x33, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.button == .right)
        #expect(event.column == 5)
        #expect(event.row == 3)
    }

    @Test("Parse middle click")
    func parseMiddleClick() throws {
        // SGR: <1;1;1M
        let bytes: [UInt8] = [0x3C, 0x31, 0x3B, 0x31, 0x3B, 0x31, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.button == .middle)
    }

    @Test("Parse button release")
    func parseRelease() throws {
        // SGR: <0;10;20m (lowercase m = release)
        let bytes: [UInt8] = [0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x6D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.button == .release)
    }

    @Test("Parse scroll up")
    func parseScrollUp() throws {
        // SGR: <64;10;20M (bit 6 set = scroll, bit 0 clear = up)
        let bytes: [UInt8] = [0x3C, 0x36, 0x34, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.button == .scrollUp)
    }

    @Test("Parse scroll down")
    func parseScrollDown() throws {
        // SGR: <65;10;20M (bit 6 set = scroll, bit 0 set = down)
        let bytes: [UInt8] = [0x3C, 0x36, 0x35, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.button == .scrollDown)
    }

    @Test("Parse with shift modifier")
    func parseShiftModifier() throws {
        // SGR: <4;10;20M (bit 2 = shift)
        let bytes: [UInt8] = [0x3C, 0x34, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.modifiers.contains(.shift))
    }

    @Test("Parse with alt modifier")
    func parseAltModifier() throws {
        // SGR: <8;10;20M (bit 3 = alt/meta)
        let bytes: [UInt8] = [0x3C, 0x38, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.modifiers.contains(.alt))
    }

    @Test("Parse with ctrl modifier")
    func parseCtrlModifier() throws {
        // SGR: <16;10;20M (bit 4 = ctrl)
        let bytes: [UInt8] = [0x3C, 0x31, 0x36, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D]
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.modifiers.contains(.ctrl))
    }

    @Test("Parse empty bytes returns nil")
    func parseEmpty() {
        #expect(MouseMode.parse([]) == nil)
    }

    @Test("Parse malformed bytes returns nil")
    func parseMalformed() {
        #expect(MouseMode.parse([0x41, 0x42, 0x43]) == nil)
    }

    @Test("MouseEvent equality")
    func eventEquality() {
        let a = MouseEvent(button: .left, column: 5, row: 10)
        let b = MouseEvent(button: .left, column: 5, row: 10)
        #expect(a == b)
    }

    @Test("MouseEvent inequality with different button")
    func eventInequality() {
        let a = MouseEvent(button: .left, column: 5, row: 10)
        let b = MouseEvent(button: .right, column: 5, row: 10)
        #expect(a != b)
    }

    @Test("Negative coordinates in SGR return nil (malformed)")
    func outOfBoundsNegativeCoords() {
        // "<0;-1;-1M" as bytes: '<' '0' ';' '-' '1' ';' '-' '1' 'M'
        let bytes: [UInt8] = [0x3C, 0x30, 0x3B, 0x2D, 0x31, 0x3B, 0x2D, 0x31, 0x4D]
        let event = MouseMode.parse(bytes)
        #expect(event == nil)
    }

    @Test("Very large coordinates parse successfully without crashing")
    func veryLargeCoords() throws {
        // "<0;99999;99999M" as bytes
        let bytes: [UInt8] = Array("<0;99999;99999M".utf8)
        let event = try #require(MouseMode.parse(bytes))
        #expect(event.column == 99999)
        #expect(event.row == 99999)
    }
}
