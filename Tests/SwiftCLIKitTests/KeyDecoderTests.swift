// KeyDecoderTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-25.

import Testing
import Foundation
@testable import SwiftCLIKit

/// `KeyDecoder` was written against `KeyReader` as it stood before the decoder existed: every
/// sequence below is read both ways, and the keys must agree, including what a sequence cut off
/// by end of input resolves to. These passed against that reader (and caught planted mutants)
/// before `KeyReader` was moved onto the decoder. Since then they guard `KeyReader`'s read loop;
/// the independent expectations are the hand-written ones in `KeyReaderTests`,
/// `KeyReaderV2Tests` and `BracketedPasteTests`.
@Suite("KeyDecoder")
struct KeyDecoderTests {

    /// Every key a `KeyReader` reads from `bytes` before it returns `nil`.
    private static func readerKeys(_ bytes: [UInt8], maxPasteBytes: Int) -> [Key] {
        let pipe = Pipe()
        pipe.fileHandleForWriting.write(Data(bytes))
        pipe.fileHandleForWriting.closeFile()
        let reader = KeyReader(
            terminal: RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor),
            maxPasteBytes: maxPasteBytes
        )
        var keys: [Key] = []
        // Each read consumes at least one byte, so this many reads exhaust the input.
        for _ in 0...bytes.count {
            guard let key = reader.readKey() else { break }
            keys.append(key)
        }
        return keys
    }

    /// Every key a `KeyDecoder` decodes from `bytes`, then what end of input resolves.
    private static func decoderKeys(_ bytes: [UInt8], maxPasteBytes: Int) -> [Key] {
        var decoder = KeyDecoder(maxPasteBytes: maxPasteBytes)
        var keys: [Key] = []
        for byte in bytes {
            if let key = decoder.feed(byte) { keys.append(key) }
            if decoder.isFinished { return keys }
        }
        if let key = decoder.finish() { keys.append(key) }
        return keys
    }

    private static let esc: UInt8 = 0x1B
    private static let pasteStart: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]
    private static let pasteEnd: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]

    /// Sequences covering each branch of the reader: CSI, SS3, SGR mouse, tilde keys, kitty `u`,
    /// UTF-8 of each length and broken, bare and dangling escapes, and bracketed pastes.
    static let fixtures: [[UInt8]] = {
        var list: [[UInt8]] = []
        for final in Array("ABCDHFZ~u".utf8) { list.append([esc, 0x5B, final]) }
        for number in ["2", "3", "5", "6", "15", "17", "18", "19", "20", "21", "23", "24", "99", "1;5", "x"] {
            list.append([esc, 0x5B] + Array(number.utf8) + [0x7E])
        }
        list.append([esc, 0x5B] + Array("1;5A".utf8))
        list.append([esc, 0x5B] + Array("97u".utf8))
        for ss3 in Array("PQRSX".utf8) { list.append([esc, 0x4F, ss3]) }
        list.append([esc, 0x5B] + Array("<0;10;5M".utf8))
        list.append([esc, 0x5B] + Array("<0;10;5m".utf8))
        list.append([esc, 0x5B] + Array("<nonsense M".utf8))
        list.append([esc, Array("x".utf8)[0]])
        list.append([esc])
        list.append([esc, esc])
        list.append(Array("é".utf8))
        list.append(Array("€".utf8))
        list.append(Array("𝄞".utf8))
        list.append([0xC3, 0x41])
        list.append([0xE2, 0x82])
        list.append([0xF8])
        list.append([0x80])
        list.append(pasteStart + Array("hello\nworld".utf8) + pasteEnd)
        list.append(pasteStart + Array("pässwörd 🔑".utf8) + pasteEnd)
        list.append(pasteStart + [esc, 0x5B, 0x41, 0x03] + pasteEnd)
        list.append(pasteStart + [0xFF, 0xFE] + pasteEnd)
        list.append(pasteStart + pasteEnd)
        return list
    }()

    @Test("Every single byte decodes as KeyReader reads it", arguments: 0...255)
    func singleByte(_ value: Int) {
        let byte = UInt8(truncatingIfNeeded: value)
        for bytes in [[byte], [byte, 0x61]] {
            #expect(Self.decoderKeys(bytes, maxPasteBytes: 64) == Self.readerKeys(bytes, maxPasteBytes: 64))
        }
    }

    @Test("Each fixture, and every truncation of it, decodes as KeyReader reads it")
    func fixturesAndTruncations() {
        for fixture in Self.fixtures {
            for length in 0...fixture.count {
                let bytes = Array(fixture.prefix(length))
                #expect(
                    Self.decoderKeys(bytes, maxPasteBytes: 64) == Self.readerKeys(bytes, maxPasteBytes: 64),
                    "bytes \(bytes)"
                )
            }
        }
    }

    @Test("Fixtures run together decode as KeyReader reads them")
    func fixturePairs() {
        for first in Self.fixtures {
            for second in Self.fixtures {
                let bytes = first + second
                #expect(
                    Self.decoderKeys(bytes, maxPasteBytes: 64) == Self.readerKeys(bytes, maxPasteBytes: 64),
                    "bytes \(bytes)"
                )
            }
        }
    }

    @Test("A paste over the cap is refused whole, as KeyReader refuses it")
    func pasteOverCap() {
        let bytes = Self.pasteStart + Array("0123456789".utf8) + Self.pasteEnd + [0x61]
        #expect(Self.decoderKeys(bytes, maxPasteBytes: 4) == Self.readerKeys(bytes, maxPasteBytes: 4))
        #expect(Self.decoderKeys(bytes, maxPasteBytes: 4) == [.unknown(0x1B), .character("a")])
    }

    @Test("A paste with no end marker past four times the cap ends input, as KeyReader ends it")
    func unterminatedPaste() {
        let bytes = Self.pasteStart + [UInt8](repeating: 0x61, count: 40) + [0x62]
        #expect(Self.decoderKeys(bytes, maxPasteBytes: 4) == Self.readerKeys(bytes, maxPasteBytes: 4))
        var decoder = KeyDecoder(maxPasteBytes: 4)
        for byte in bytes { _ = decoder.feed(byte) }
        #expect(decoder.isFinished)
    }

    /// With a cap of 4 the read budget is 4 × 4 + 6 = 22 bytes after the start marker: a body of
    /// 16 bytes plus the end marker lands on the last of them, and one more byte runs past it.
    @Test("The paste read budget ends exactly where KeyReader's does", arguments: 14...18)
    func pasteBudgetBoundary(_ bodyLength: Int) {
        let bytes = Self.pasteStart + [UInt8](repeating: 0x61, count: bodyLength) + Self.pasteEnd + [0x62]
        #expect(Self.decoderKeys(bytes, maxPasteBytes: 4) == Self.readerKeys(bytes, maxPasteBytes: 4))
    }

    // MARK: - Bounds KeyReader never had

    @Test("CSI parameters past the cap are discarded through the final byte, holding nothing")
    func csiParameterCap() {
        var decoder = KeyDecoder()
        var keys: [Key] = []
        let bytes: [UInt8] = [0x1B, 0x5B] + [UInt8](repeating: 0x31, count: 10_000)
        for byte in bytes {
            if let key = decoder.feed(byte) { keys.append(key) }
        }
        #expect(keys.isEmpty)
        #expect(decoder.feed(0x41) == .unknown(0x1B))
        #expect(decoder.feed(0x61) == .character("a"))
    }

    @Test("One parameter byte past the cap discards the sequence")
    func csiPastCap() {
        var decoder = KeyDecoder()
        let params = [UInt8](repeating: 0x31, count: KeyDecoder.maxSequenceBytes + 1)
        let keys = ([0x1B, 0x5B] + params + [0x41]).compactMap { decoder.feed($0) }
        #expect(keys == [.unknown(0x1B)])
    }

    @Test("An SGR mouse report one byte past the cap is discarded")
    func mousePastCap() {
        var decoder = KeyDecoder()
        // The report's bytes, counted from its '<', reach the cap plus one before 'M'.
        let digits = [UInt8](repeating: 0x31, count: KeyDecoder.maxSequenceBytes)
        let keys = ([0x1B, 0x5B, 0x3C] + digits + [0x4D]).compactMap { decoder.feed($0) }
        #expect(keys == [.unknown(0x1B)])
    }

    @Test("A sequence at the cap still decodes")
    func csiAtCap() {
        var decoder = KeyDecoder()
        let params = [UInt8](repeating: 0x31, count: KeyDecoder.maxSequenceBytes)
        let keys = ([0x1B, 0x5B] + params + [0x41]).compactMap { decoder.feed($0) }
        #expect(keys == [.arrowUp])
    }

    @Test("An SGR mouse report past the cap is discarded through its final byte, holding nothing")
    func mouseCap() {
        var decoder = KeyDecoder()
        var keys: [Key] = []
        let bytes: [UInt8] = [0x1B, 0x5B, 0x3C] + [UInt8](repeating: 0x31, count: 10_000)
        for byte in bytes {
            if let key = decoder.feed(byte) { keys.append(key) }
        }
        #expect(keys.isEmpty)
        #expect(decoder.feed(0x4D) == .unknown(0x1B))
        #expect(decoder.finish() == nil)
    }

    @Test("Input that ends inside an over-long sequence resolves as an unknown key")
    func overflowAtEndOfInput() {
        var decoder = KeyDecoder()
        for byte in [0x1B, 0x5B] + [UInt8](repeating: 0x31, count: 200) { _ = decoder.feed(byte) }
        #expect(decoder.finish() == .unknown(0x1B))
    }

    @Test("A decoder returns to its ground state after each key")
    func reusable() {
        var decoder = KeyDecoder()
        let bytes: [UInt8] = [0x1B, 0x5B, 0x41, 0x61, 0x1B, 0x4F, 0x50]
        let keys = bytes.compactMap { decoder.feed($0) }
        #expect(keys == [.arrowUp, .character("a"), .functionKey(1)])
        #expect(decoder.finish() == nil)
    }
}
