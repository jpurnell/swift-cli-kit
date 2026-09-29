// KeyReaderV2Tests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("KeyReader v0.2.0")
struct KeyReaderV2Tests {

    private func readerFromBytes(_ bytes: [UInt8]) -> KeyReader {
        let pipe = Pipe()
        pipe.fileHandleForWriting.write(Data(bytes))
        pipe.fileHandleForWriting.closeFile()
        let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        return KeyReader(terminal: terminal)
    }

    // MARK: - Function keys

    @Test("F1 escape sequence ESC O P")
    func f1() {
        let reader = readerFromBytes([0x1B, 0x4F, 0x50])
        #expect(reader.readKey() == .functionKey(1))
    }

    @Test("F2 escape sequence ESC O Q")
    func f2() {
        let reader = readerFromBytes([0x1B, 0x4F, 0x51])
        #expect(reader.readKey() == .functionKey(2))
    }

    @Test("F3 escape sequence ESC O R")
    func f3() {
        let reader = readerFromBytes([0x1B, 0x4F, 0x52])
        #expect(reader.readKey() == .functionKey(3))
    }

    @Test("F4 escape sequence ESC O S")
    func f4() {
        let reader = readerFromBytes([0x1B, 0x4F, 0x53])
        #expect(reader.readKey() == .functionKey(4))
    }

    @Test("F5 escape sequence ESC[15~")
    func f5() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x31, 0x35, 0x7E])
        #expect(reader.readKey() == .functionKey(5))
    }

    @Test("F12 escape sequence ESC[24~")
    func f12() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x32, 0x34, 0x7E])
        #expect(reader.readKey() == .functionKey(12))
    }

    // MARK: - Navigation keys

    @Test("PageUp escape sequence ESC[5~")
    func pageUp() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x35, 0x7E])
        #expect(reader.readKey() == .pageUp)
    }

    @Test("PageDown escape sequence ESC[6~")
    func pageDown() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x36, 0x7E])
        #expect(reader.readKey() == .pageDown)
    }

    @Test("Insert escape sequence ESC[2~")
    func insert() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x32, 0x7E])
        #expect(reader.readKey() == .insert)
    }

    // MARK: - Mouse

    @Test("Mouse SGR left click sequence")
    func mouseSGR() {
        // ESC [ < 0 ; 1 0 ; 2 0 M
        let reader = readerFromBytes([0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D])
        let key = reader.readKey()
        if case .mouse(let event) = key {
            #expect(event.button == .left)
            #expect(event.column == 10)
            #expect(event.row == 20)
        } else {
            #expect(Bool(false), "Expected .mouse case but got \(String(describing: key))")
        }
    }

    // MARK: - Kitty protocol statics

    @Test("enableKittyProtocol is ESC[>1u")
    func enableKitty() {
        #expect(KeyReader.enableKittyProtocol == "\u{001B}[>1u")
    }

    @Test("disableKittyProtocol is ESC[<u")
    func disableKitty() {
        #expect(KeyReader.disableKittyProtocol == "\u{001B}[<u")
    }

    // MARK: - Regression

    @Test("Arrow up still works after v0.2.0 changes")
    func arrowUpRegression() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x41])
        #expect(reader.readKey() == .arrowUp)
    }

    @Test("Kitty statics are non-empty and standard arrow-up still parses correctly")
    func standardKeysWithKittyStatics() {
        // Verify Kitty protocol statics are non-empty strings
        #expect(!KeyReader.enableKittyProtocol.isEmpty)
        #expect(!KeyReader.disableKittyProtocol.isEmpty)

        // Verify that a standard arrow-up sequence still parses as .arrowUp
        // (regression guard: the protocol statics don't alter the parser state)
        let reader = readerFromBytes([0x1B, 0x5B, 0x41])
        #expect(reader.readKey() == .arrowUp)
    }
}
