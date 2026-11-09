// OSCColorReply.swift
// SwiftCLIKit

import Foundation

/// A terminal's reply to an OSC 10 (foreground) or OSC 11 (background) colour query.
///
/// This type only parses bytes that the caller has already read. It performs no terminal I/O.
public struct OSCColorReply: Sendable, Equatable {

    /// Which default colour the reply describes.
    public enum Target: Sendable, Equatable {
        /// OSC 10: the default foreground.
        case foreground
        /// OSC 11: the default background.
        case background
    }

    /// Which colour was reported.
    public let target: Target
    /// The reported colour, scaled to 8 bits per channel.
    public let color: TerminalRGB

    /// Creates a reply value.
    public init(target: Target, color: TerminalRGB) {
        self.target = target
        self.color = color
    }

    private static let esc: UInt8 = 0x1B
    private static let bel: UInt8 = 0x07
    private static let backslash: UInt8 = 0x5C
    private static let rightBracket: UInt8 = 0x5D

    /// Parses the first OSC 10 or OSC 11 reply in `input`.
    ///
    /// Accepted forms are `ESC ] 11 ; rgb:R/G/B` with one to four hex digits per channel
    /// (scaled to 8 bits), and `ESC ] 11 ; #RRGGBB`, each ended by BEL or `ESC \`.
    /// Bytes after the terminator, such as a following device-attributes reply, are ignored.
    ///
    /// - Parameter input: The raw reply text.
    /// - Returns: The parsed reply, or `nil` if it is malformed, truncated or out of range.
    public static func parse(_ input: String) -> OSCColorReply? {
        let bytes = Array(input.utf8)
        guard bytes.count >= 5 else { return nil }
        guard bytes[0] == esc, bytes[1] == rightBracket else { return nil }

        let target: Target
        switch (bytes[2], bytes[3], bytes[4]) {
        case (0x31, 0x30, 0x3B): target = .foreground   // "10;"
        case (0x31, 0x31, 0x3B): target = .background   // "11;"
        default: return nil
        }

        var payload: [UInt8] = []
        var terminated = false
        var index = 5
        while index < bytes.count {
            let byte = bytes[index]
            if byte == bel {
                terminated = true
                break
            }
            if byte == esc {
                guard index + 1 < bytes.count, bytes[index + 1] == backslash else { return nil }
                terminated = true
                break
            }
            payload.append(byte)
            index += 1
        }
        guard terminated else { return nil }
        guard let text = String(bytes: payload, encoding: .utf8) else { return nil }

        guard let color = parseColor(text) else { return nil }
        return OSCColorReply(target: target, color: color)
    }

    private static func parseColor(_ text: String) -> TerminalRGB? {
        if text.hasPrefix("#") {
            guard text.count == 7, allHex(text.dropFirst()) else { return nil }
            return TerminalRGB(hex: text)
        }
        guard text.hasPrefix("rgb:") else { return nil }
        let channels = text.dropFirst(4).split(separator: "/", omittingEmptySubsequences: false)
        guard channels.count == 3 else { return nil }
        guard let r = scale(channels[0]), let g = scale(channels[1]), let b = scale(channels[2]) else {
            return nil
        }
        return TerminalRGB(r: r, g: g, b: b)
    }

    private static func allHex(_ text: Substring) -> Bool {
        text.utf8.allSatisfy { $0.isHexDigit }
    }

    /// Scales a 1 to 4 digit hex channel to 8 bits, rounding to nearest.
    private static func scale(_ digits: Substring) -> UInt8? {
        guard (1...4).contains(digits.count), allHex(digits) else { return nil }
        guard let value = Int(digits, radix: 16) else { return nil }
        let maximum = (1 << (4 * digits.count)) - 1
        guard maximum > 0 else { return nil }
        let scaled = (value * 255 + maximum / 2) / maximum
        return UInt8(clamping: scaled)
    }
}

private extension UInt8 {
    var isHexDigit: Bool {
        (0x30...0x39).contains(self) || (0x41...0x46).contains(self) || (0x61...0x66).contains(self)
    }
}
