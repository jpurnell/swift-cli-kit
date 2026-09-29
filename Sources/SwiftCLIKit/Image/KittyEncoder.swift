// KittyEncoder.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Encodes image data for the Kitty graphics protocol.
///
/// The Kitty protocol transmits images as chunked base64 data within APC escape sequences.
/// Each chunk is at most ``defaultChunkSize`` bytes of base64 payload.
///
/// ```swift
/// let pngData: [UInt8] = Array(Data())  // raw PNG file bytes
/// let sequence = KittyEncoder.encode(data: pngData, width: 40, height: 20)
/// print(sequence) // writes image to Kitty-compatible terminal
/// ```
public struct KittyEncoder: Sendable {

    /// Maximum chunk size for base64 payload per escape sequence (4096 bytes).
    public static let defaultChunkSize: Int = 4096

    /// Encode image file data (PNG or JPEG) for the Kitty graphics protocol.
    ///
    /// Returns a string of one or more APC escape sequences with chunked base64 payload.
    /// - Parameters:
    ///   - data: Raw PNG or JPEG file bytes.
    ///   - width: Desired display width in terminal cells (nil for auto).
    ///   - height: Desired display height in terminal cells (nil for auto).
    ///   - chunkSize: Maximum base64 bytes per chunk (default: 4096).
    /// - Returns: Escape sequence string ready to write to terminal.
    public static func encode(
        data: [UInt8],
        width: Int? = nil,
        height: Int? = nil,
        chunkSize: Int = defaultChunkSize
    ) -> String {
        guard !data.isEmpty else { return "" }
        guard chunkSize > 0 else { return "" }

        let base64 = Data(data).base64EncodedString()
        var chunks: [String] = []
        var startIndex = base64.startIndex

        while startIndex < base64.endIndex {
            let endIndex = base64.index(startIndex,
                                        offsetBy: chunkSize,
                                        limitedBy: base64.endIndex) ?? base64.endIndex
            chunks.append(String(base64[startIndex..<endIndex]))
            startIndex = endIndex
        }

        guard !chunks.isEmpty else { return "" }

        var result = ""
        for (index, chunk) in chunks.enumerated() {
            let isLast = index == chunks.count - 1
            let moreFlag = isLast ? 0 : 1

            // Build the header parameters
            var params = "a=T,f=100,m=\(moreFlag)"
            if index == 0 {
                if let w = width {
                    params += ",c=\(w)"
                }
                if let h = height {
                    params += ",r=\(h)"
                }
            }

            // APC sequence: ESC _ G <params> ; <payload> ESC \
            result += "\u{1B}_G\(params);\(chunk)\u{1B}\\"
        }

        return result
    }
}
