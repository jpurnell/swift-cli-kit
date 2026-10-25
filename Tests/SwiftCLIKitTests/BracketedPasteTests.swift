// BracketedPasteTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-24.

import Testing
import Foundation
@testable import SwiftCLIKit

/// Bracketed paste (xterm mode 2004): `ESC [ 200 ~` … `ESC [ 201 ~` arrives as one ``Key/paste(_:)``.
@Suite("Bracketed paste")
struct BracketedPasteTests {

    private static let pasteStart: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]
    private static let pasteEnd: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]

    private func readerFromBytes(_ bytes: [UInt8], maxPasteBytes: Int? = nil) -> KeyReader {
        let pipe = Pipe()
        let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        // Write from another thread: a paste larger than the pipe buffer would
        // otherwise block the writer before the reader starts.
        let writer = pipe.fileHandleForWriting
        let data = Data(bytes)
        Thread {
            writer.write(data)
            writer.closeFile()
        }.start()
        if let maxPasteBytes {
            return KeyReader(terminal: terminal, maxPasteBytes: maxPasteBytes)
        }
        return KeyReader(terminal: terminal)
    }

    private func bracketed(_ text: String) -> [UInt8] {
        Self.pasteStart + Array(text.utf8) + Self.pasteEnd
    }

    /// 64 code points drawn from 1-, 2-, 3- and 4-byte UTF-8 encodings.
    static let unicodePassword: String = {
        let scalars: [Unicode.Scalar] = ["a", "é", "ß", "Ω", "日", "本", "🔑", "Z", "ж", "🦊", "9", "€", "ü", "中", "#", "ø"]
        var out = String.UnicodeScalarView()
        for index in 0..<64 {
            out.append(scalars[index % scalars.count])
        }
        return String(out)
    }()

    // MARK: - Golden path

    @Test("ASCII paste arrives as a single paste key")
    func asciiPaste() {
        let reader = readerFromBytes(bracketed("hunter2"))
        #expect(reader.readKey() == .paste("hunter2"))
        #expect(reader.readKey() == nil)
    }

    @Test("A 64-code-point Unicode password arrives whole")
    func unicodePasswordWhole() {
        let password = Self.unicodePassword
        #expect(password.unicodeScalars.count == 64)
        let reader = readerFromBytes(bracketed(password))
        let key = reader.readKey()
        #expect(key == .paste(password))
        if case .paste(let text) = key {
            #expect(text.unicodeScalars.count == 64)
            #expect(Array(text.utf8) == Array(password.utf8))
        }
    }

    @Test("Newlines, tabs and ESC bytes inside a paste are content, not keys")
    func controlBytesAreContent() {
        let content = "line1\nline2\r\tq\u{1B}[Az\u{1B}\u{7F}\u{03}"
        let reader = readerFromBytes(bracketed(content))
        #expect(reader.readKey() == .paste(content))
        #expect(reader.readKey() == nil)
    }

    @Test("A partial end marker inside the paste is content")
    func partialEndMarkerIsContent() {
        let content = "a\u{1B}[20b\u{1B}[201x\u{1B}[200~c"
        let reader = readerFromBytes(bracketed(content))
        #expect(reader.readKey() == .paste(content))
    }

    @Test("An empty paste yields an empty paste key")
    func emptyPaste() {
        let reader = readerFromBytes(Self.pasteStart + Self.pasteEnd)
        #expect(reader.readKey() == .paste(""))
    }

    @Test("Keys before and after a paste decode normally")
    func surroundingKeys() {
        let bytes: [UInt8] = [0x41] + bracketed("x y") + [0x1B, 0x5B, 0x41, 0x0D]
        let reader = readerFromBytes(bytes)
        #expect(reader.readKey() == .character("A"))
        #expect(reader.readKey() == .paste("x y"))
        #expect(reader.readKey() == .arrowUp)
        #expect(reader.readKey() == .enter)
    }

    @Test("A paste split across separate writes is delivered whole")
    func splitAcrossReads() {
        let password = Self.unicodePassword
        let bytes = bracketed(password)
        // Split inside a multi-byte scalar and inside the end marker.
        let firstCut = Self.pasteStart.count + 2
        let secondCut = bytes.count - 3
        let pipe = Pipe()
        let writer = pipe.fileHandleForWriting
        writer.write(Data(bytes[0..<firstCut]))
        let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        let reader = KeyReader(terminal: terminal)
        let tail1 = Data(bytes[firstCut..<secondCut])
        let tail2 = Data(bytes[secondCut...])
        let thread = Thread {
            Thread.sleep(forTimeInterval: 0.05)
            writer.write(tail1)
            Thread.sleep(forTimeInterval: 0.05)
            writer.write(tail2)
            writer.closeFile()
        }
        thread.start()
        #expect(reader.readKey() == .paste(password))
    }

    // MARK: - Invalid input

    @Test("EOF before the end marker yields nil, not a partial paste")
    func eofMidPaste() {
        let reader = readerFromBytes(Self.pasteStart + Array("half".utf8))
        #expect(reader.readKey() == nil)
    }

    @Test("Invalid UTF-8 inside a paste is refused, not replaced")
    func invalidUTF8Refused() {
        let reader = readerFromBytes(Self.pasteStart + [0x61, 0xFF, 0x62] + Self.pasteEnd + [0x41])
        #expect(reader.readKey() == .unknown(0x1B))
        #expect(reader.readKey() == .character("A"))
    }

    @Test("A paste over the byte cap is refused whole and the stream stays in sync")
    func overCapRefused() {
        let bytes = bracketed("abcdefghij") + [0x42]
        let reader = readerFromBytes(bytes, maxPasteBytes: 4)
        #expect(reader.readKey() == .unknown(0x1B))
        #expect(reader.readKey() == .character("B"))
    }

    @Test("A paste exactly at the byte cap is delivered")
    func atCapDelivered() {
        let reader = readerFromBytes(bracketed("abcd"), maxPasteBytes: 4)
        #expect(reader.readKey() == .paste("abcd"))
    }

    @Test("The default cap holds a large paste whole")
    func largePasteDefaultCap() {
        let big = String(repeating: "Ω🔑a", count: 10_000)
        let reader = readerFromBytes(bracketed(big))
        #expect(reader.readKey() == .paste(big))
        #expect(KeyReader.defaultMaxPasteBytes >= 1_048_576)
    }

    @Test("A stray paste end marker is not a paste")
    func strayEndMarker() {
        let reader = readerFromBytes(Self.pasteEnd + [0x41])
        #expect(reader.readKey() == .unknown(0x7E))
        #expect(reader.readKey() == .character("A"))
    }

    // MARK: - Mode sequences

    @Test("Bracketed paste enable/disable sequences are xterm mode 2004")
    func modeSequences() {
        #expect(ANSICodes.enableBracketedPaste == "\u{001B}[?2004h")
        #expect(ANSICodes.disableBracketedPaste == "\u{001B}[?2004l")
    }

    // MARK: - LineEditor

    @Test("A paste into a LineEditor inserts the text at the cursor")
    func lineEditorPaste() {
        var editor = LineEditor(text: "ab")
        _ = editor.handleKey(.arrowLeft)
        let result = editor.handleKey(.paste("日本🔑"))
        #expect(result == .editing)
        #expect(editor.text == "a日本🔑b")
        #expect(editor.cursorPosition == 4)
    }

    @Test("A paste that begins with a combining mark keeps the cursor inside the text")
    func lineEditorCombiningPaste() {
        var editor = LineEditor(text: "e")
        _ = editor.handleKey(.paste("\u{301}x"))
        #expect(editor.text == "e\u{301}x")
        #expect(editor.text.count == 2)
        #expect(editor.cursorPosition == 2)
    }

    @Test("A paste into a TextField reports the change")
    func textFieldPaste() {
        var field = TextField(text: "x")
        #expect(field.handleKey(.paste("yz")) == .changed("xyz"))
    }
}
