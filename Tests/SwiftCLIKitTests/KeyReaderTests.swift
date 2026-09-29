// KeyReaderTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("KeyReader")
struct KeyReaderTests {

    private func readerFromBytes(_ bytes: [UInt8]) -> KeyReader {
        let pipe = Pipe()
        pipe.fileHandleForWriting.write(Data(bytes))
        pipe.fileHandleForWriting.closeFile()
        let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        return KeyReader(terminal: terminal)
    }

    @Test("Arrow up escape sequence")
    func arrowUp() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x41])
        #expect(reader.readKey() == .arrowUp)
    }

    @Test("Arrow down escape sequence")
    func arrowDown() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x42])
        #expect(reader.readKey() == .arrowDown)
    }

    @Test("Arrow right escape sequence")
    func arrowRight() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x43])
        #expect(reader.readKey() == .arrowRight)
    }

    @Test("Arrow left escape sequence")
    func arrowLeft() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x44])
        #expect(reader.readKey() == .arrowLeft)
    }

    @Test("Home escape sequence")
    func home() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x48])
        #expect(reader.readKey() == .home)
    }

    @Test("End escape sequence")
    func end() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x46])
        #expect(reader.readKey() == .end)
    }

    @Test("Delete escape sequence")
    func delete() {
        let reader = readerFromBytes([0x1B, 0x5B, 0x33, 0x7E])
        #expect(reader.readKey() == .delete)
    }

    @Test("Backspace byte")
    func backspace() {
        let reader = readerFromBytes([0x7F])
        #expect(reader.readKey() == .backspace)
    }

    @Test("Enter / carriage return byte")
    func enter() {
        let reader = readerFromBytes([0x0D])
        #expect(reader.readKey() == .enter)
    }

    @Test("Tab byte")
    func tab() {
        let reader = readerFromBytes([0x09])
        #expect(reader.readKey() == .tab)
    }

    @Test("Ctrl-C byte")
    func ctrlC() {
        let reader = readerFromBytes([0x03])
        #expect(reader.readKey() == .ctrlC)
    }

    @Test("Ctrl-D byte")
    func ctrlD() {
        let reader = readerFromBytes([0x04])
        #expect(reader.readKey() == .ctrlD)
    }

    @Test("Ctrl-A byte")
    func ctrlA() {
        let reader = readerFromBytes([0x01])
        #expect(reader.readKey() == .ctrlA)
    }

    @Test("Ctrl-E byte")
    func ctrlE() {
        let reader = readerFromBytes([0x05])
        #expect(reader.readKey() == .ctrlE)
    }

    @Test("Ctrl-K byte")
    func ctrlK() {
        let reader = readerFromBytes([0x0B])
        #expect(reader.readKey() == .ctrlK)
    }

    @Test("Ctrl-W byte")
    func ctrlW() {
        let reader = readerFromBytes([0x17])
        #expect(reader.readKey() == .ctrlW)
    }

    @Test("Ctrl-U byte")
    func ctrlU() {
        let reader = readerFromBytes([0x15])
        #expect(reader.readKey() == .ctrlU)
    }

    @Test("Ctrl-L byte")
    func ctrlL() {
        let reader = readerFromBytes([0x0C])
        #expect(reader.readKey() == .ctrlL)
    }

    @Test("Printable ASCII character 'a'")
    func printableASCII() {
        let reader = readerFromBytes([0x61])
        #expect(reader.readKey() == .character("a"))
    }

    @Test("UTF-8 multibyte character e-acute")
    func utf8Multibyte() {
        let reader = readerFromBytes([0xC3, 0xA9])
        #expect(reader.readKey() == .character("\u{00E9}"))
    }

    @Test("Unknown control byte NUL")
    func unknownControl() {
        let reader = readerFromBytes([0x00])
        #expect(reader.readKey() == .unknown(0x00))
    }

    @Test("Bare escape byte returns something (stub returns nil, so this fails)")
    func bareEscape() {
        let reader = readerFromBytes([0x1B])
        let result = reader.readKey()
        #expect(result == .escape)
    }

    @Test("Bare escape on pipe EOF returns .escape, not hang")
    func malformedEscapeSequence() {
        // Write just ESC (0x1B) with no following bytes, then close the pipe.
        // The reader should return .escape when the next readByte returns nil (EOF).
        let reader = readerFromBytes([0x1B])
        let result = reader.readKey()
        #expect(result == .escape)
    }
}
