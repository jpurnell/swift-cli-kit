// Clipboard.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation
#if canImport(os)
import os
#endif

/// Terminal clipboard access via OSC 52 escape sequences.
///
/// OSC 52 allows reading and writing the system clipboard through the
/// terminal emulator without platform-specific APIs.
///
/// ```swift
/// Clipboard.write("Hello, clipboard!")
/// let sequence = Clipboard.writeSequence("text")
/// ```
public enum Clipboard {
    #if canImport(os)
    private static let logger = Logger(subsystem: "com.swiftclikit", category: "Clipboard")
    #endif

    /// Writes text to the clipboard by printing the OSC 52 sequence.
    /// - Parameter text: The text to copy to the clipboard.
    public static func write(_ text: String) {
        let sequence = writeSequence(text)
        #if canImport(os)
        logger.debug("Writing OSC 52 clipboard sequence")
        #endif
        FileHandle.standardOutput.write(Data(sequence.utf8))
    }

    /// Returns the OSC 52 escape sequence to write text to the clipboard.
    /// - Parameter text: The text to encode.
    /// - Returns: The OSC 52 escape sequence string.
    public static func writeSequence(_ text: String) -> String {
        let base64 = Data(text.utf8).base64EncodedString()
        return "\u{1B}]52;c;\(base64)\u{07}"
    }

    /// Reads text from the clipboard via OSC 52 (requires terminal support).
    /// - Parameter timeout: How long to wait for the terminal response.
    /// - Returns: The clipboard contents, or `nil` on timeout.
    /// Many terminals block the read response; returns nil for v1.0.0.
    public static func read(timeout: Duration = .seconds(1)) async -> String? {
        nil
    }

    /// Returns the OSC 52 escape sequence to request clipboard contents.
    /// - Returns: The OSC 52 read-request escape sequence.
    public static func readSequence() -> String {
        "\u{1B}]52;c;?\u{07}"
    }
}
