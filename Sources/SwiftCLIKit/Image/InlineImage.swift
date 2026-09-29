// InlineImage.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A widget-like struct for displaying inline images in the terminal.
///
/// `InlineImage` auto-detects the best available image protocol and produces
/// the appropriate escape sequence. When no protocol is available, it falls back
/// to ASCII art rendering using half-block Unicode characters.
///
/// ```swift
/// // Display a PNG via the best available protocol. `pngBytes` is the raw file.
/// let pngBytes: [UInt8] = Array(Data())
/// let pixels = PixelData(bytes: [UInt8](repeating: 0, count: 4 * 100 * 50),
///                        width: 100, height: 50)
///
/// let image = InlineImage(fileData: pngBytes, width: 40, height: 20)
/// if let seq = image.escapeSequence() {
///     print(seq)
/// }
///
/// // Force ASCII art rendering
/// let ascii = InlineImage(pixelData: pixels, capability: .none)
/// let cells = ascii.renderASCII(width: 40, height: 20)
/// ```
public struct InlineImage: Sendable {

    /// Raw image file bytes (PNG or JPEG). Used by Kitty and iTerm2 encoders.
    public var fileData: [UInt8]?

    /// Decoded pixel data (RGBA). Used by Sixel encoder and ASCII art fallback.
    public var pixelData: PixelData?

    /// Desired display width in terminal cells. Nil for auto-sizing.
    public var width: Int?

    /// Desired display height in terminal cells. Nil for auto-sizing.
    public var height: Int?

    /// Explicit capability override. Nil for auto-detection.
    public var capability: ImageCapability?

    /// Creates an inline image.
    /// - Parameters:
    ///   - fileData: Raw PNG or JPEG file bytes.
    ///   - pixelData: Decoded RGBA pixel data.
    ///   - width: Display width in terminal cells (nil for auto).
    ///   - height: Display height in terminal cells (nil for auto).
    ///   - capability: Explicit protocol override (nil for auto-detect).
    public init(
        fileData: [UInt8]? = nil,
        pixelData: PixelData? = nil,
        width: Int? = nil,
        height: Int? = nil,
        capability: ImageCapability? = nil
    ) {
        self.fileData = fileData
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.capability = capability
    }

    /// The effective capability, resolving auto-detection if not explicitly set.
    public var resolvedCapability: ImageCapability {
        if let cap = capability {
            return cap
        }
        return ImageCapabilityDetector.detect()
    }

    /// Produce the escape sequence for rendering via a graphics protocol.
    ///
    /// Returns `nil` if the resolved capability is `.none` (use ``renderASCII(width:height:)``
    /// instead for fallback rendering).
    /// - Returns: An escape sequence string, or nil for `.none` capability.
    public func escapeSequence() -> String? {
        escapeSequence(capability: resolvedCapability)
    }

    /// Produce the escape sequence for a specific capability.
    /// - Parameter capability: The image protocol to use.
    /// - Returns: An escape sequence string, or nil for `.none`.
    public func escapeSequence(capability: ImageCapability) -> String? {
        switch capability {
        case .kitty:
            guard let data = fileData else { return nil }
            return KittyEncoder.encode(data: data, width: width, height: height)

        case .iterm2:
            guard let data = fileData else { return nil }
            return ITermEncoder.encode(data: data, width: width, height: height)

        case .sixel:
            guard let pixels = pixelData else { return nil }
            return SixelEncoder.encode(pixels: pixels)

        case .none:
            return nil
        }
    }

    /// Render the image as ASCII art using half-block characters.
    ///
    /// Used when capability is `.none` or as an explicit fallback.
    /// Requires ``pixelData`` to be set; returns empty array if nil.
    /// - Parameters:
    ///   - width: Target width in terminal cells.
    ///   - height: Target height in terminal cells.
    /// - Returns: 2D array of ``Cell`` values.
    public func renderASCII(width: Int, height: Int) -> [[Cell]] {
        guard let pixels = pixelData else { return [] }
        return ASCIIArt.render(pixels: pixels, width: width, height: height)
    }
}

/// Encodes image data for the iTerm2 inline image protocol (OSC 1337).
///
/// ```swift
/// let pngData: [UInt8] = Array(Data())  // raw PNG file bytes
/// let sequence = ITermEncoder.encode(data: pngData)
/// print(sequence) // writes image to iTerm2-compatible terminal
/// ```
public struct ITermEncoder: Sendable {

    /// Encode image file data for the iTerm2 inline image protocol.
    /// - Parameters:
    ///   - data: Raw PNG or JPEG file bytes.
    ///   - width: Display width in terminal cells (nil for auto).
    ///   - height: Display height in terminal cells (nil for auto).
    ///   - preserveAspectRatio: Whether to maintain aspect ratio (default true).
    /// - Returns: Escape sequence string.
    public static func encode(
        data: [UInt8],
        width: Int? = nil,
        height: Int? = nil,
        preserveAspectRatio: Bool = true
    ) -> String {
        guard !data.isEmpty else { return "" }

        let base64 = Data(data).base64EncodedString()
        let widthParam = width.map { "\($0)" } ?? "auto"
        let heightParam = height.map { "\($0)" } ?? "auto"
        let aspectFlag = preserveAspectRatio ? 1 : 0
        let size = data.count

        return "\u{1B}]1337;File=inline=1;size=\(size);width=\(widthParam);height=\(heightParam);preserveAspectRatio=\(aspectFlag):\(base64)\u{07}"
    }
}
