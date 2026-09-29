// MouseEvent.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A mouse button or scroll action.
public enum MouseButton: Sendable, Equatable {
    case left, middle, right, scrollUp, scrollDown, release
}

/// A decoded mouse event from the terminal.
public struct MouseEvent: Sendable, Equatable {
    /// The button or scroll action.
    public let button: MouseButton
    /// The 1-based column where the event occurred.
    public let column: Int
    /// The 1-based row where the event occurred.
    public let row: Int
    /// Any modifier keys held during the event.
    public let modifiers: KeyModifiers

    /// Creates a mouse event.
    public init(button: MouseButton, column: Int, row: Int, modifiers: KeyModifiers = []) {
        self.button = button
        self.column = column
        self.row = row
        self.modifiers = modifiers
    }

    /// Modifier keys that can accompany a mouse event.
    public struct KeyModifiers: OptionSet, Sendable, Equatable {
        /// The raw integer value of the option set.
        public let rawValue: UInt8
        /// Creates a key-modifier option set from a raw value.
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        /// Shift key.
        public static let shift = KeyModifiers(rawValue: 1 << 0)
        /// Alt/Option key.
        public static let alt = KeyModifiers(rawValue: 1 << 1)
        /// Control key.
        public static let ctrl = KeyModifiers(rawValue: 1 << 2)
    }
}

/// SGR mouse protocol control sequences and parser.
///
/// Enable mouse reporting, read and parse events, then disable when done.
///
/// ```swift
/// // Enable SGR mouse mode
/// print(MouseMode.enable, terminator: "")
///
/// // In your input loop, detect the CSI < prefix and collect bytes:
/// let sgrBytes: [UInt8] = Array("\u{1B}[<0;10;5M".utf8)
/// func handleClick(_ column: Int, _ row: Int) {}
/// func scrollUp() {}
///
/// if let event = MouseMode.parse(sgrBytes) {
///     switch event.button {
///     case .left:  handleClick(event.column, event.row)
///     case .scrollUp: scrollUp()
///     default: break
///     }
/// }
///
/// // Disable when the application exits
/// print(MouseMode.disable, terminator: "")
/// ```
public enum MouseMode {
    /// Enables SGR extended mouse mode.
    public static let enable = "\u{001B}[?1000h\u{001B}[?1006h"
    /// Disables SGR extended mouse mode.
    public static let disable = "\u{001B}[?1000l\u{001B}[?1006l"

    /// Parses SGR mouse bytes (after the CSI `<` prefix) into a ``MouseEvent``.
    /// - Parameter bytes: The raw bytes of the SGR sequence including `<`, digits, separators, and final `M`/`m`.
    /// - Returns: A decoded ``MouseEvent``, or `nil` if the bytes are malformed.
    public static func parse(_ bytes: [UInt8]) -> MouseEvent? {
        guard bytes.count >= 6 else { return nil }
        guard bytes.first == 0x3C else { return nil } // must start with '<'

        let lastByte = bytes.last
        guard lastByte == 0x4D || lastByte == 0x6D else { return nil } // M or m
        let isRelease = lastByte == 0x6D

        // Strip '<' and final 'M'/'m', then split on ';'
        let middle = bytes[bytes.startIndex + 1 ..< bytes.endIndex - 1]
        let parts = splitOnSemicolon(middle)
        guard parts.count == 3 else { return nil }

        guard let btnCode = parseNumber(parts[0]),
              let col = parseNumber(parts[1]),
              let row = parseNumber(parts[2]) else { return nil }

        let baseBtn = btnCode & 0x03
        let isScroll = (btnCode & 64) != 0
        let shiftMod = (btnCode & 4) != 0
        let altMod = (btnCode & 8) != 0
        let ctrlMod = (btnCode & 16) != 0

        let button: MouseButton
        if isRelease {
            button = .release
        } else if isScroll {
            button = baseBtn == 0 ? .scrollUp : .scrollDown
        } else {
            switch baseBtn {
            case 0: button = .left
            case 1: button = .middle
            case 2: button = .right
            default: button = .left
            }
        }

        var mods = MouseEvent.KeyModifiers()
        if shiftMod { mods.insert(.shift) }
        if altMod { mods.insert(.alt) }
        if ctrlMod { mods.insert(.ctrl) }

        return MouseEvent(button: button, column: col, row: row, modifiers: mods)
    }

    private static func splitOnSemicolon(_ bytes: ArraySlice<UInt8>) -> [ArraySlice<UInt8>] {
        var result: [ArraySlice<UInt8>] = []
        var start = bytes.startIndex
        for i in bytes.indices {
            if bytes[i] == 0x3B { // ';'
                result.append(bytes[start..<i])
                start = i + 1
            }
        }
        result.append(bytes[start..<bytes.endIndex])
        return result
    }

    private static func parseNumber(_ bytes: ArraySlice<UInt8>) -> Int? {
        guard !bytes.isEmpty else { return nil }
        var n = 0
        for b in bytes {
            guard b >= 0x30 && b <= 0x39 else { return nil }
            n = n * 10 + Int(b - 0x30)
        }
        return n
    }
}
