// ColorTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Color")
struct ColorTests {

    @Test("fromHex valid 6-digit hex with hash")
    func fromHexValid6Digit() {
        let color = Color.fromHex("#FF8800")
        #expect(color == .truecolor(r: 0xFF, g: 0x88, b: 0x00))
    }

    @Test("fromHex valid 6-digit hex without hash")
    func fromHexNoHash() {
        let color = Color.fromHex("FF8800")
        #expect(color == .truecolor(r: 0xFF, g: 0x88, b: 0x00))
    }

    @Test("fromHex valid 3-digit shorthand expands correctly")
    func fromHex3Digit() {
        let color = Color.fromHex("#F80")
        #expect(color == .truecolor(r: 0xFF, g: 0x88, b: 0x00))
    }

    @Test("fromHex invalid string returns nil")
    func fromHexInvalid() {
        #expect(Color.fromHex("not-a-color") == nil)
    }

    @Test("fromHex empty string returns nil")
    func fromHexEmpty() {
        #expect(Color.fromHex("") == nil)
    }

    @Test("Equatable: same truecolor values are equal")
    func equatable() {
        let a = Color.truecolor(r: 10, g: 20, b: 30)
        let b = Color.truecolor(r: 10, g: 20, b: 30)
        #expect(a == b)
    }

    @Test("Downsample truecolor to basic yields nearest ANSI color")
    func downsampleTruecolorToBasic() {
        let red = Color.truecolor(r: 0xFF, g: 0x00, b: 0x00)
        let result = red.downsampled(to: .basic)
        #expect(result == .ansi8(.red))
    }

    @Test("Downsample truecolor to extended yields ansi256 index")
    func downsampleTruecolorToExtended() {
        let color = Color.truecolor(r: 0xFF, g: 0x00, b: 0x00)
        let result = color.downsampled(to: .extended)
        if case .ansi256 = result {
            // Expected an ansi256 case
        } else {
            #expect(Bool(false), "Expected .ansi256 case but got \(result)")
        }
    }

    @Test("Downsample to none returns ansi8 black or special sentinel")
    func downsampleToNone() {
        let color = Color.truecolor(r: 0xFF, g: 0x00, b: 0x00)
        let result = color.downsampled(to: .none)
        // At .none capability, downsampled should strip color entirely
        #expect(result != .truecolor(r: 0xFF, g: 0x00, b: 0x00))
    }

    @Test("Downsample basic stays basic")
    func downsampleBasicStaysBasic() {
        let color = Color.ansi8(.green)
        let result = color.downsampled(to: .basic)
        #expect(result == .ansi8(.green))
    }

    @Test("Downsample ansi256 to basic yields ansi8")
    func downsample256ToBasic() {
        let color = Color.ansi256(196)  // bright red in 256 palette
        let result = color.downsampled(to: .basic)
        if case .ansi8 = result {
            // Expected an ansi8 case
        } else {
            #expect(Bool(false), "Expected .ansi8 case but got \(result)")
        }
    }
}
