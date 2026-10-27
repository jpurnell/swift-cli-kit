// KeyDecoder.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-25.

import Foundation

/// Decodes terminal input into ``Key`` values one byte at a time, for input that arrives in
/// pieces: an SSH channel, a socket, a test.
///
/// ``KeyReader`` reads a ``RawTerminal`` through this decoder, so a key decodes the same way
/// however its bytes arrive. Feed each byte as it comes; a byte that completes a key returns it.
/// When the input ends, ``finish()`` resolves a sequence left incomplete, such as a lone `ESC`.
///
/// ```swift
/// var decoder = KeyDecoder()
/// var keys: [Key] = []
/// for byte: UInt8 in [0x1B, 0x5B, 0x41, 0x61] {   // ESC [ A, then "a"
///     if let key = decoder.feed(byte) { keys.append(key) }
/// }
/// // keys == [.arrowUp, .character("a")]
/// ```
///
/// A lone `ESC` is held until the next byte says whether it starts a sequence, as ``KeyReader``
/// holds it. A byte after `ESC` that starts no sequence is consumed with it.
public struct KeyDecoder: Sendable {

    /// How many times the cap a refused paste may run before its end marker
    /// before the decoder stops looking for one.
    static let refusedPasteReadFactor = 4

    /// The parameter bytes of the bracketed paste start marker, `200`.
    static let pasteStartParams: [UInt8] = [0x32, 0x30, 0x30]

    /// The most bytes a CSI sequence's parameters, or an SGR mouse report, may hold: far above
    /// any real one (`ESC [ < 0 ; 1000 ; 1000 M` is 16), so input that never sends a final byte
    /// can't grow the decoder. Past it, bytes are discarded through the final byte and the
    /// sequence decodes as `.unknown(0x1B)`.
    static let maxSequenceBytes = 64

    /// Where the decoder is in a key's bytes.
    private enum State: Sendable {
        /// Between keys.
        case ground
        /// After `ESC`.
        case escape
        /// After `ESC O`.
        case ss3
        /// After `ESC [`, before any parameter byte.
        case csiStart
        /// Inside an SGR mouse report, `ESC [ <`.
        case mouse([UInt8])
        /// Inside a CSI sequence, with the parameter bytes so far.
        case csi([UInt8])
        /// Discarding a CSI sequence longer than ``maxSequenceBytes`` until its final byte.
        case overlongCSI
        /// Discarding an SGR mouse report longer than ``maxSequenceBytes`` until its final byte.
        case overlongMouse
        /// Inside a bracketed paste, with the bytes it may still read.
        case paste(PasteBody, remaining: Int)
        /// Inside a UTF-8 sequence.
        case utf8(first: UInt8, remaining: Int, value: UInt32)
    }

    private var state: State = .ground


    /// The largest bracketed paste, in UTF-8 bytes, delivered as ``Key/paste(_:)``.
    public let maxPasteBytes: Int

    /// Whether input has been ended by a paste that ran past four times ``maxPasteBytes`` with
    /// no end marker. ``KeyReader`` returns `nil` there, as at end of input; once set, nothing
    /// more is decoded.
    public private(set) var isFinished = false

    /// Creates a decoder.
    /// - Parameter maxPasteBytes: The largest bracketed paste, in UTF-8 bytes, to deliver. A
    ///   longer paste is refused whole, never truncated, and reported as ``Key/unknown(_:)``.
    ///   Negative values are treated as zero. Defaults to ``KeyReader/defaultMaxPasteBytes``.
    public init(maxPasteBytes: Int = KeyReader.defaultMaxPasteBytes) {
        self.maxPasteBytes = max(0, maxPasteBytes)
    }

    /// Decodes one byte.
    /// - Parameter byte: The next byte of input.
    /// - Returns: The key this byte completes, or `nil` while a key is still incomplete.
    public mutating func feed(_ byte: UInt8) -> Key? {
        guard !isFinished else { return nil }
        switch state {
        case .ground:
            return ground(byte)
        case .escape:
            return escape(byte)
        case .ss3:
            state = .ground
            return Self.ss3(byte)
        case .csiStart:
            return csiStart(byte)
        case .mouse(let bytes):
            return mouse(bytes + [byte])
        case .csi(let params):
            return csi(params, byte)
        case .overlongCSI:
            return discard(isFinal: byte >= 0x40 && byte <= 0x7E, else: .overlongCSI)
        case .overlongMouse:
            return discard(isFinal: byte == 0x4D || byte == 0x6D, else: .overlongMouse)
        case .paste(let body, let remaining):
            return paste(body, remaining: remaining, byte)
        case let .utf8(first, remaining, value):
            return utf8(first: first, remaining: remaining, value: value, byte)
        }
    }

    /// Whether the decoder is between keys, with no key begun.
    var isBetweenKeys: Bool {
        if case .ground = state { return true }
        return false
    }

    /// Whether the last byte was an ESC that may or may not begin a sequence.
    var isAfterLoneEscape: Bool {
        if case .escape = state { return true }
        return false
    }

    /// Ends the input, resolving a key left incomplete as ``KeyReader`` resolves it at end of
    /// input: a dangling escape as ``Key/escape``, a cut-off character or mouse report as
    /// ``Key/unknown(_:)``, a cut-off paste as nothing.
    /// - Returns: What the incomplete key resolves to, or `nil` if there was none.
    public mutating func finish() -> Key? {
        defer { state = .ground }
        switch state {
        case .ground, .paste:
            return nil
        case .escape, .ss3, .csiStart, .csi:
            return .escape
        case .mouse, .overlongCSI, .overlongMouse:
            return .unknown(0x1B)
        case .utf8(let first, _, _):
            return .unknown(first)
        }
    }

    // MARK: - States

    private mutating func ground(_ byte: UInt8) -> Key? {
        switch byte {
        case 0x00: return .unknown(0x00)
        case 0x01: return .ctrlA
        case 0x03: return .ctrlC
        case 0x04: return .ctrlD
        case 0x05: return .ctrlE
        case 0x09: return .tab
        case 0x0A, 0x0D: return .enter
        case 0x0B: return .ctrlK
        case 0x0C: return .ctrlL
        case 0x15: return .ctrlU
        case 0x17: return .ctrlW
        case 0x1B:
            state = .escape
            return nil
        case 0x7F: return .backspace
        case 0x00...0x7F: return .character(Character(UnicodeScalar(byte)))
        case 0xC0...0xDF:
            state = .utf8(first: byte, remaining: 1, value: UInt32(byte & 0x1F))
            return nil
        case 0xE0...0xEF:
            state = .utf8(first: byte, remaining: 2, value: UInt32(byte & 0x0F))
            return nil
        case 0xF0...0xF7:
            state = .utf8(first: byte, remaining: 3, value: UInt32(byte & 0x07))
            return nil
        default:
            return .unknown(byte)
        }
    }

    private mutating func escape(_ byte: UInt8) -> Key? {
        switch byte {
        case 0x4F:
            state = .ss3
            return nil
        case 0x5B:
            state = .csiStart
            return nil
        default:
            // ESC followed by something other than '[' or 'O': a bare escape.
            state = .ground
            return .escape
        }
    }

    /// `ESC O <letter>`: F1 to F4.
    private static func ss3(_ byte: UInt8) -> Key {
        switch byte {
        case 0x50: return .functionKey(1) // P
        case 0x51: return .functionKey(2) // Q
        case 0x52: return .functionKey(3) // R
        case 0x53: return .functionKey(4) // S
        default: return .unknown(byte)
        }
    }

    private mutating func csiStart(_ byte: UInt8) -> Key? {
        if byte == 0x3C { // '<': an SGR mouse report
            state = .mouse([0x3C])
            return nil
        }
        return csi([], byte)
    }

    private mutating func mouse(_ bytes: [UInt8]) -> Key? {
        guard let last = bytes.last, last == 0x4D || last == 0x6D else { // 'M' or 'm'
            state = bytes.count > Self.maxSequenceBytes ? .overlongMouse : .mouse(bytes)
            return nil
        }
        state = .ground
        if let event = MouseMode.parse(bytes) {
            return .mouse(event)
        }
        return .unknown(0x1B)
    }

    private mutating func csi(_ params: [UInt8], _ byte: UInt8) -> Key? {
        guard byte >= 0x40 && byte <= 0x7E else {
            state = params.count < Self.maxSequenceBytes ? .csi(params + [byte]) : .overlongCSI
            return nil
        }
        state = .ground
        if byte == 0x7E, params == Self.pasteStartParams {
            let markerCount = PasteBody.endMarker.count
            let (scaled, overflow) = maxPasteBytes.multipliedReportingOverflow(by: Self.refusedPasteReadFactor)
            let budget = overflow ? Int.max : scaled + markerCount
            state = .paste(PasteBody(maxBytes: maxPasteBytes), remaining: budget)
            return nil
        }
        return Self.mapCSI(params: params, finalByte: byte)
    }

    /// One byte of an over-long sequence: discarded, until the final byte ends it as unknown.
    private mutating func discard(isFinal: Bool, else waiting: State) -> Key? {
        guard isFinal else {
            state = waiting
            return nil
        }
        state = .ground
        return .unknown(0x1B)
    }

    /// One byte of a bracketed paste body, after `ESC [ 200 ~`.
    ///
    /// Bytes are collected first and decoded once, so a character split across reads arrives
    /// whole. Memory is bounded by ``maxPasteBytes``: past it the body is discarded while the
    /// decoder scans for the end marker.
    private mutating func paste(_ body: PasteBody, remaining: Int, _ byte: UInt8) -> Key? {
        var body = body
        if body.append(byte) {
            state = .ground
            return body.key()
        }
        guard remaining > 1 else {
            state = .ground
            isFinished = true
            return nil
        }
        state = .paste(body, remaining: remaining - 1)
        return nil
    }

    private mutating func utf8(first: UInt8, remaining: Int, value: UInt32, _ byte: UInt8) -> Key? {
        guard byte & 0xC0 == 0x80 else {
            state = .ground
            return .unknown(first)
        }
        let next = (value << 6) | UInt32(byte & 0x3F)
        guard remaining <= 1 else {
            state = .utf8(first: first, remaining: remaining - 1, value: next)
            return nil
        }
        state = .ground
        guard let scalar = Unicode.Scalar(next) else { return .unknown(first) }
        return .character(Character(scalar))
    }

    // MARK: - CSI

    private static func mapCSI(params: [UInt8], finalByte: UInt8) -> Key {
        switch finalByte {
        case 0x41: return .arrowUp // A
        case 0x42: return .arrowDown // B
        case 0x43: return .arrowRight // C
        case 0x44: return .arrowLeft // D
        case 0x48: return .home // H
        case 0x46: return .end // F
        case 0x5A: return .backtab // Z (Shift-Tab)
        case 0x7E: return mapTildeSequence(params: params) // ~
        default: return .unknown(finalByte)
        }
    }

    private static func mapTildeSequence(params: [UInt8]) -> Key {
        // Convert param bytes (ASCII digits) to an integer
        var number = 0
        for b in params {
            guard b >= 0x30 && b <= 0x39 else { return .unknown(0x7E) }
            number = number * 10 + Int(b - 0x30)
        }
        switch number {
        case 2: return .insert
        case 3: return .delete
        case 5: return .pageUp
        case 6: return .pageDown
        case 15: return .functionKey(5)
        case 17: return .functionKey(6)
        case 18: return .functionKey(7)
        case 19: return .functionKey(8)
        case 20: return .functionKey(9)
        case 21: return .functionKey(10)
        case 23: return .functionKey(11)
        case 24: return .functionKey(12)
        default: return .unknown(0x7E)
        }
    }
}

/// The body of one bracketed paste as it arrives, byte by byte.
struct PasteBody: Sendable {
    /// The bracketed paste end marker, `ESC [ 2 0 1 ~`.
    static let endMarker: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]

    /// The most bytes held: the cap plus an end marker not yet recognised.
    private let keepLimit: Int
    private var content: [UInt8] = []
    private var window: [UInt8] = []
    private var refused = false

    init(maxBytes: Int) {
        self.keepLimit = maxBytes + Self.endMarker.count
    }

    /// Adds one byte. Returns `true` when it completes the end marker.
    mutating func append(_ byte: UInt8) -> Bool {
        window.append(byte)
        if window.count > Self.endMarker.count {
            window.removeFirst()
        }
        if !refused {
            content.append(byte)
            refused = content.count > keepLimit
            if refused { content.removeAll() }
        }
        return window == Self.endMarker
    }

    /// The finished paste: its text, or `.unknown(0x1B)` when it was over the cap
    /// or is not valid UTF-8. Call once ``append(_:)`` has returned `true`.
    func key() -> Key {
        guard !refused, content.count >= Self.endMarker.count else { return .unknown(0x1B) }
        let text = content.dropLast(Self.endMarker.count)
        guard let decoded = String(bytes: text, encoding: .utf8) else { return .unknown(0x1B) }
        return .paste(decoded)
    }
}
