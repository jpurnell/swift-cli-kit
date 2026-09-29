// ImageTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

// MARK: - ImageCapability Detection Tests

@Suite("ImageCapabilityDetector")
struct ImageCapabilityDetectorTests {

    @Test("Empty environment returns .none")
    func detectEmptyEnvironment() {
        let result = ImageCapabilityDetector.detect(environment: [:])
        #expect(result == .none)
    }

    @Test("TERM_PROGRAM=kitty returns .kitty")
    func detectKittyTermProgram() {
        let env = ["TERM_PROGRAM": "kitty"]
        #expect(ImageCapabilityDetector.detect(environment: env) == .kitty)
    }

    @Test("KITTY_WINDOW_ID present returns .kitty")
    func detectKittyWindowId() {
        let env = ["KITTY_WINDOW_ID": "1"]
        #expect(ImageCapabilityDetector.detect(environment: env) == .kitty)
    }

    @Test("TERM_PROGRAM=iTerm.app returns .iterm2")
    func detectITerm() {
        let env = ["TERM_PROGRAM": "iTerm.app"]
        #expect(ImageCapabilityDetector.detect(environment: env) == .iterm2)
    }

    @Test("SWIFTCLIKIT_IMAGE_PROTOCOL=sixel overrides detection")
    func detectOverride() {
        let env = [
            "SWIFTCLIKIT_IMAGE_PROTOCOL": "sixel",
            "TERM_PROGRAM": "kitty"
        ]
        #expect(ImageCapabilityDetector.detect(environment: env) == .sixel)
    }

    @Test("WezTerm detected as .kitty")
    func detectWezTerm() {
        let env = ["TERM_PROGRAM": "WezTerm"]
        #expect(ImageCapabilityDetector.detect(environment: env) == .kitty)
    }
}

// MARK: - KittyEncoder Tests

@Suite("KittyEncoder")
struct KittyEncoderTests {

    @Test("Small data produces single chunk with m=0")
    func singleChunk() {
        let data: [UInt8] = [0x89, 0x50, 0x4E, 0x47]  // PNG magic bytes
        let result = KittyEncoder.encode(data: data)
        #expect(result.contains("m=0"))
        #expect(result.hasPrefix("\u{1B}_G"))
        #expect(result.hasSuffix("\u{1B}\\"))
    }

    @Test("Large data produces multiple chunks with correct m flags")
    func multipleChunks() {
        // Create data that produces base64 output larger than one chunk
        let data = [UInt8](repeating: 0xFF, count: 4096)
        let result = KittyEncoder.encode(data: data, chunkSize: 100)
        // Should have multiple chunks: all but last have m=1, last has m=0
        #expect(result.contains("m=1"))
        #expect(result.contains("m=0"))
        // Count the number of ESC_G sequences
        let chunkCount = result.components(separatedBy: "\u{1B}_G").count - 1
        #expect(chunkCount > 1)
    }

    @Test("Width and height appear as c= and r=")
    func widthHeightParams() {
        let data: [UInt8] = [1, 2, 3]
        let result = KittyEncoder.encode(data: data, width: 40, height: 20)
        #expect(result.contains("c=40"))
        #expect(result.contains("r=20"))
    }

    @Test("Empty data returns empty string")
    func emptyData() {
        let result = KittyEncoder.encode(data: [])
        #expect(result.isEmpty)
    }

    @Test("Payload is valid base64 of input data")
    func validBase64Payload() {
        let data: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
        let result = KittyEncoder.encode(data: data)
        let expectedBase64 = Data(data).base64EncodedString()
        #expect(result.contains(expectedBase64))
    }
}

// MARK: - SixelEncoder Tests

@Suite("SixelEncoder")
struct SixelEncoderTests {

    @Test("Output starts with DCS header and ends with ST")
    func headerAndFooter() throws {
        let pixels = try #require(PixelData(
            bytes: [255, 0, 0, 255, 0, 255, 0, 255,
                    0, 0, 255, 255, 255, 255, 0, 255],
            width: 2, height: 2
        ))
        let result = SixelEncoder.encode(pixels: pixels)
        #expect(result.hasPrefix("\u{1B}Pq"))
        #expect(result.hasSuffix("\u{1B}\\"))
    }

    @Test("Color palette entries formatted correctly")
    func paletteFormat() throws {
        // Single red pixel
        let pixels = try #require(PixelData(bytes: [255, 0, 0, 255], width: 1, height: 1))
        let result = SixelEncoder.encode(pixels: pixels)
        // Red = 100%, Green = 0%, Blue = 0%
        #expect(result.contains("#0;2;100;0;0"))
    }

    @Test("Zero-dimension pixels returns empty string")
    func zeroDimension() {
        let result = SixelEncoder.encode(pixels: .empty)
        #expect(result.isEmpty)
    }
}

// MARK: - ASCIIArt Tests

@Suite("ASCIIArt")
struct ASCIIArtTests {

    @Test("2x2 pixels renders to 1x1 cell grid")
    func twoByTwoToOneByOne() throws {
        // 2 columns, 2 rows of red pixels
        let pixels = try #require(PixelData(
            bytes: [255, 0, 0, 255, 255, 0, 0, 255,
                    255, 0, 0, 255, 255, 0, 0, 255],
            width: 2, height: 2
        ))
        let result = ASCIIArt.render(pixels: pixels, width: 1, height: 1)
        #expect(result.count == 1)
        #expect(result[0].count == 1)
        // Should have upper half block with red fg and red bg
        #expect(result[0][0].character == "\u{2580}")
        #expect(result[0][0].fg == .truecolor(r: 255, g: 0, b: 0))
        #expect(result[0][0].bg == .truecolor(r: 255, g: 0, b: 0))
    }

    @Test("Empty pixels returns empty result")
    func emptyPixels() {
        let result = ASCIIArt.render(
            pixels: .empty,
            width: 10, height: 5
        )
        #expect(result.isEmpty)
    }

    @Test("Zero target dimensions returns empty result")
    func zeroTargetDimensions() throws {
        let pixels = try #require(PixelData(bytes: [255, 0, 0, 255], width: 1, height: 1))
        let result = ASCIIArt.render(pixels: pixels, width: 0, height: 0)
        #expect(result.isEmpty)
    }

    @Test("Scale produces correct output dimensions")
    func scaleOutputDimensions() throws {
        let pixels = try #require(PixelData(
            bytes: [UInt8](repeating: 255, count: 10 * 10 * 4),
            width: 10, height: 10
        ))
        let scaled = ASCIIArt.scale(pixels: pixels, targetWidth: 5, targetHeight: 5)
        #expect(scaled.width == 5)
        #expect(scaled.height == 5)
    }
}

// MARK: - InlineImage Tests

@Suite("InlineImage")
struct InlineImageTests {

    @Test("Kitty capability uses KittyEncoder")
    func kittyEscapeSequence() throws {
        let data: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let image = InlineImage(fileData: data, capability: .kitty)
        let result = try #require(image.escapeSequence())
        #expect(result.hasPrefix("\u{1B}_G"))
    }

    @Test("None capability returns nil escape sequence")
    func noneReturnsNil() {
        let image = InlineImage(fileData: [1, 2, 3], capability: ImageCapability.none)
        let result = image.escapeSequence()
        #expect(result == nil)
    }

    @Test("iTerm2 capability uses ITermEncoder")
    func itermEscapeSequence() throws {
        let data: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let image = InlineImage(fileData: data, capability: .iterm2)
        let result = try #require(image.escapeSequence())
        #expect(result.contains("1337;File="))
    }

    @Test("renderASCII without pixelData returns empty")
    func renderASCIINoPixelData() {
        let image = InlineImage(capability: ImageCapability.none)
        let result = image.renderASCII(width: 10, height: 5)
        #expect(result.isEmpty)
    }

    @Test("renderASCII with pixelData returns cells")
    func renderASCIIWithPixelData() throws {
        let pixels = try #require(PixelData(
            bytes: [255, 0, 0, 255, 0, 255, 0, 255,
                    0, 0, 255, 255, 255, 255, 0, 255],
            width: 2, height: 2
        ))
        let image = InlineImage(pixelData: pixels, capability: ImageCapability.none)
        let result = image.renderASCII(width: 2, height: 1)
        #expect(result.count == 1)
        #expect(result[0].count == 2)
    }
}

// MARK: - PixelData Tests

@Suite("PixelData")
struct PixelDataTests {

    @Test("Pixel access returns correct RGBA values")
    func pixelAccess() throws {
        let bytes: [UInt8] = [10, 20, 30, 40, 50, 60, 70, 80]
        let pixels = try #require(PixelData(bytes: bytes, width: 2, height: 1))
        let p0 = try #require(pixels.pixel(x: 0, y: 0))
        #expect(p0.r == 10)
        #expect(p0.g == 20)
        #expect(p0.b == 30)
        #expect(p0.a == 40)
        let p1 = try #require(pixels.pixel(x: 1, y: 0))
        #expect(p1.r == 50)
        #expect(p1.g == 60)
        #expect(p1.b == 70)
        #expect(p1.a == 80)
    }
}
