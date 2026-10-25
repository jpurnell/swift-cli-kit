// KeyReader.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Decodes raw bytes from a ``RawTerminal`` into structured ``Key`` values,
/// handling UTF-8 multi-byte sequences and CSI escape codes.
///
/// ```swift
/// let pipe = Pipe()
/// pipe.fileHandleForWriting.write(Data([0x1B, 0x5B, 0x41]))  // arrow-up
/// pipe.fileHandleForWriting.closeFile()
/// let reader = KeyReader(terminal: RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor))
/// let key = reader.readKey()  // .arrowUp
/// ```
public struct KeyReader: Sendable {
    /// Enable Kitty keyboard protocol: \u{001B}[>1u
    public static let enableKittyProtocol = "\u{001B}[>1u"
    /// Disable Kitty keyboard protocol: \u{001B}[<u
    public static let disableKittyProtocol = "\u{001B}[<u"

    /// The default largest bracketed paste, in UTF-8 bytes, that ``readKey()`` delivers: 1 MiB.
    ///
    /// Far above any password or passphrase, so a secret is never refused for its
    /// length; low enough that an unterminated paste cannot exhaust memory.
    public static let defaultMaxPasteBytes = 1_048_576

    /// How many times the cap a refused paste may run before its end marker
    /// before the reader stops looking for one.
    private static let refusedPasteReadFactor = 4

    /// The parameter bytes of the bracketed paste start marker, `200`.
    private static let pasteStartParams: [UInt8] = [0x32, 0x30, 0x30]

    private let terminal: RawTerminal

    /// The largest bracketed paste, in UTF-8 bytes, delivered as ``Key/paste(_:)``.
    public let maxPasteBytes: Int

    /// Creates a key reader that pulls bytes from the given raw terminal.
    /// - Parameters:
    ///   - terminal: The ``RawTerminal`` to read from.
    ///   - maxPasteBytes: The largest bracketed paste, in UTF-8 bytes, to deliver.
    ///     A longer paste is refused whole — never truncated — and reported as
    ///     ``Key/unknown(_:)``. Negative values are treated as zero.
    ///     Defaults to ``defaultMaxPasteBytes``.
    public init(terminal: RawTerminal, maxPasteBytes: Int = KeyReader.defaultMaxPasteBytes) {
        self.terminal = terminal
        self.maxPasteBytes = max(0, maxPasteBytes)
    }

    /// Reads and decodes the next key press, blocking until a byte is available.
    ///
    /// A bracketed paste (`ESC [ 200 ~` … `ESC [ 201 ~`) is returned as one
    /// ``Key/paste(_:)`` holding the whole pasted text, however many reads it spans.
    /// Bytes inside it — newlines, `ESC`, control bytes — are content, not keys.
    /// A paste that is not valid UTF-8, or is longer than ``maxPasteBytes``, is
    /// consumed through its end marker and refused as `.unknown(0x1B)`; it is
    /// never truncated or repaired. A paste cut off by EOF, or that runs past four
    /// times the cap without an end marker, returns `nil`.
    /// - Returns: The decoded ``Key``, or `nil` on EOF.
    public func readKey() -> Key? {
        guard let byte = terminal.readByte() else { return nil }

        switch byte {
        case 0x00:
            return .unknown(0x00)
        case 0x01:
            return .ctrlA
        case 0x03:
            return .ctrlC
        case 0x04:
            return .ctrlD
        case 0x05:
            return .ctrlE
        case 0x09:
            return .tab
        case 0x0A, 0x0D:
            return .enter
        case 0x0B:
            return .ctrlK
        case 0x0C:
            return .ctrlL
        case 0x15:
            return .ctrlU
        case 0x17:
            return .ctrlW
        case 0x1B:
            return readEscapeSequence()
        case 0x7F:
            return .backspace
        default:
            if byte < 0x80 {
                return .character(Character(UnicodeScalar(byte)))
            }
            return readUTF8(firstByte: byte)
        }
    }

    private func readEscapeSequence() -> Key? {
        guard let next = terminal.readByte() else { return .escape }

        // SS3 sequences: ESC O <letter> — F1-F4
        if next == 0x4F {
            guard let ss3Byte = terminal.readByte() else { return .escape }
            switch ss3Byte {
            case 0x50: return .functionKey(1) // P
            case 0x51: return .functionKey(2) // Q
            case 0x52: return .functionKey(3) // R
            case 0x53: return .functionKey(4) // S
            default: return .unknown(ss3Byte)
            }
        }

        guard next == 0x5B else {
            // ESC followed by something other than '[' or 'O' — return bare escape
            return .escape
        }

        // CSI sequence: ESC [ <params> <final>
        // Check for SGR mouse: ESC [ < ...
        guard let firstParam = terminal.readByte() else { return .escape }

        if firstParam == 0x3C { // '<' — SGR mouse sequence
            var mouseBytes: [UInt8] = [0x3C]
            while true { // SAFETY: Loop terminates on EOF (guard-nil return) or 'M'/'m' final byte (break). SGR mouse sequences are bounded: CSI < Cb;Cx;Cy M/m — at most ~20 bytes.
                guard let mb = terminal.readByte() else { return .unknown(0x1B) }
                mouseBytes.append(mb)
                if mb == 0x4D || mb == 0x6D { // 'M' or 'm'
                    break
                }
            }
            if let event = MouseMode.parse(mouseBytes) {
                return .mouse(event)
            }
            return .unknown(0x1B)
        }

        // Regular CSI: collect parameter bytes until final byte (0x40-0x7E)
        var params: [UInt8] = []
        if firstParam >= 0x40 && firstParam <= 0x7E {
            return mapCSI(params: params, finalByte: firstParam)
        }
        params.append(firstParam)

        while true { // SAFETY: Loop terminates on EOF (guard-nil return) or when a CSI final byte in range 0x40-0x7E is received (return). CSI params are bounded by protocol.
            guard let paramByte = terminal.readByte() else { return .escape }
            if paramByte >= 0x40 && paramByte <= 0x7E {
                // Final byte
                return mapCSI(params: params, finalByte: paramByte)
            }
            params.append(paramByte)
        }
    }

    private func mapCSI(params: [UInt8], finalByte: UInt8) -> Key? {
        switch finalByte {
        case 0x41: // A
            return .arrowUp
        case 0x42: // B
            return .arrowDown
        case 0x43: // C
            return .arrowRight
        case 0x44: // D
            return .arrowLeft
        case 0x48: // H
            return .home
        case 0x46: // F
            return .end
        case 0x5A: // Z (Shift-Tab / Backtab)
            return .backtab
        case 0x7E: // ~
            if params == Self.pasteStartParams {
                return readPaste()
            }
            return mapTildeSequence(params: params)
        default:
            return .unknown(finalByte)
        }
    }

    private func mapTildeSequence(params: [UInt8]) -> Key {
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

    /// Reads a bracketed paste body through its end marker, after `ESC [ 200 ~`.
    ///
    /// Bytes are collected first and decoded once, so a character split across
    /// reads arrives whole. Memory is bounded by ``maxPasteBytes``: past it the
    /// body is discarded while the reader scans for the end marker.
    private func readPaste() -> Key? {
        let markerCount = PasteBody.endMarker.count
        let (scaled, overflow) = maxPasteBytes.multipliedReportingOverflow(by: Self.refusedPasteReadFactor)
        let readBudget = overflow ? Int.max : scaled + markerCount
        var body = PasteBody(maxBytes: maxPasteBytes)

        for _ in 0..<readBudget {
            guard let byte = terminal.readByte() else { return nil }
            if body.append(byte) {
                return body.key()
            }
        }
        return nil
    }

    private func readUTF8(firstByte: UInt8) -> Key {
        let continuationCount: Int
        var value: UInt32

        switch firstByte {
        case 0xC0...0xDF:
            continuationCount = 1
            value = UInt32(firstByte & 0x1F)
        case 0xE0...0xEF:
            continuationCount = 2
            value = UInt32(firstByte & 0x0F)
        case 0xF0...0xF7:
            continuationCount = 3
            value = UInt32(firstByte & 0x07)
        default:
            return .unknown(firstByte)
        }

        for _ in 0..<continuationCount {
            guard let cont = terminal.readByte() else { return .unknown(firstByte) }
            guard cont & 0xC0 == 0x80 else { return .unknown(firstByte) }
            value = (value << 6) | UInt32(cont & 0x3F)
        }

        guard let scalar = Unicode.Scalar(value) else { return .unknown(firstByte) }
        return .character(Character(scalar))
    }
}

/// The body of one bracketed paste as it arrives, byte by byte.
private struct PasteBody {
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
