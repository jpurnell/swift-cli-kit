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

    private let terminal: RawTerminal

    /// Creates a key reader that pulls bytes from the given raw terminal.
    /// - Parameter terminal: The ``RawTerminal`` to read from.
    public init(terminal: RawTerminal) { self.terminal = terminal }

    /// Reads and decodes the next key press, blocking until a byte is available.
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

    private func readEscapeSequence() -> Key {
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

    private func mapCSI(params: [UInt8], finalByte: UInt8) -> Key {
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
