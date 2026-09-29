// CursorControlTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("CursorControl")
struct CursorControlTests {

    @Test("show produces DECTCEM show sequence")
    func showSequence() {
        #expect(CursorControl.show == "\u{001B}[?25h")
    }

    @Test("hide produces DECTCEM hide sequence")
    func hideSequence() {
        #expect(CursorControl.hide == "\u{001B}[?25l")
    }

    @Test("moveTo produces CUP sequence")
    func moveToSequence() {
        #expect(CursorControl.moveTo(row: 5, column: 10) == "\u{001B}[5;10H")
    }

    @Test("moveUp produces CUU sequence")
    func moveUpSequence() {
        #expect(CursorControl.moveUp(3) == "\u{001B}[3A")
    }

    @Test("moveDown produces CUD sequence")
    func moveDownSequence() {
        #expect(CursorControl.moveDown(2) == "\u{001B}[2B")
    }

    @Test("moveRight produces CUF sequence")
    func moveRightSequence() {
        #expect(CursorControl.moveRight(4) == "\u{001B}[4C")
    }

    @Test("moveLeft produces CUB sequence")
    func moveLeftSequence() {
        #expect(CursorControl.moveLeft(1) == "\u{001B}[1D")
    }

    @Test("save produces CSI s sequence")
    func saveSequence() {
        #expect(CursorControl.save == "\u{001B}[s")
    }

    @Test("restore produces CSI u sequence")
    func restoreSequence() {
        #expect(CursorControl.restore == "\u{001B}[u")
    }

    @Test("setShape block non-blinking produces DECSCUSR 2")
    func setShapeBlock() {
        #expect(CursorControl.setShape(.block) == "\u{001B}[2 q")
    }

    @Test("setShape block blinking produces DECSCUSR 1")
    func setShapeBlockBlinking() {
        #expect(CursorControl.setShape(.block, blinking: true) == "\u{001B}[1 q")
    }

    @Test("setShape underline non-blinking produces DECSCUSR 4")
    func setShapeUnderline() {
        #expect(CursorControl.setShape(.underline) == "\u{001B}[4 q")
    }

    @Test("setShape underline blinking produces DECSCUSR 3")
    func setShapeUnderlineBlinking() {
        #expect(CursorControl.setShape(.underline, blinking: true) == "\u{001B}[3 q")
    }

    @Test("setShape bar non-blinking produces DECSCUSR 6")
    func setShapeBar() {
        #expect(CursorControl.setShape(.bar) == "\u{001B}[6 q")
    }

    @Test("setShape bar blinking produces DECSCUSR 5")
    func setShapeBarBlinking() {
        #expect(CursorControl.setShape(.bar, blinking: true) == "\u{001B}[5 q")
    }
}
