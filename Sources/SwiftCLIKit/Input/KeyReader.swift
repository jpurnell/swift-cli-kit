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
    /// times the cap without an end marker, returns `nil`. A CSI sequence or mouse report
    /// longer than 64 bytes is discarded through its final byte and returned as
    /// `.unknown(0x1B)`. Decoding is ``KeyDecoder``'s.
    /// - Returns: The decoded ``Key``, or `nil` on EOF.
    public func readKey() -> Key? {
        var decoder = KeyDecoder(maxPasteBytes: maxPasteBytes)
        // Every byte either completes a key, advances the decoder, or ends a refused paste, so
        // this ends at end of input at the latest.
        while let byte = terminal.readByte() {
            if let key = decoder.feed(byte) { return key }
            if decoder.isFinished { return nil }
        }
        return decoder.finish()
    }
}
