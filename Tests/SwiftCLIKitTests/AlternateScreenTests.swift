// AlternateScreenTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("AlternateScreen")
struct AlternateScreenTests {

    /// A pipe is not a terminal, so these tests say so explicitly: they are about what the
    /// escape sequences are, not about how terminal-ness is decided.
    private static let pretendTerminal: @Sendable (Int32) -> Bool = { _ in true }

    @Test("Init writes enter sequence containing ESC[?1049h")
    func initWritesEnterSequence() throws {
        let pipe = Pipe()
        let fd = pipe.fileHandleForWriting.fileDescriptor
        let _ = AlternateScreen(fileDescriptor: fd, isTerminal: Self.pretendTerminal)
        pipe.fileHandleForWriting.closeFile()
        let data = try StandardInput.readAll(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        let output = String(data: data, encoding: .utf8) ?? ""
        #expect(output.contains("\u{001B}[?1049h"))
    }

    @Test("isActive is true after init")
    func isActiveAfterInit() {
        let pipe = Pipe()
        let screen = AlternateScreen(
            fileDescriptor: pipe.fileHandleForWriting.fileDescriptor,
            isTerminal: Self.pretendTerminal
        )
        #expect(screen.isActive == true)
    }

    @Test("Deinit writes leave sequence containing ESC[?1049l")
    func deinitWritesLeaveSequence() throws {
        let pipe = Pipe()
        let fd = pipe.fileHandleForWriting.fileDescriptor
        do {
            let _ = AlternateScreen(fileDescriptor: fd, isTerminal: Self.pretendTerminal)
        }
        pipe.fileHandleForWriting.closeFile()
        let data = try StandardInput.readAll(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        let output = String(data: data, encoding: .utf8) ?? ""
        #expect(output.contains("\u{001B}[?1049l"))
    }

    @Test("A non-terminal file descriptor is not written to at all")
    func nonTerminalIsLeftAlone() throws {
        let pipe = Pipe()
        let fd = pipe.fileHandleForWriting.fileDescriptor
        do {
            let screen = AlternateScreen(fileDescriptor: fd, isTerminal: { _ in false })
            #expect(screen.isActive == false)
        }
        pipe.fileHandleForWriting.closeFile()
        let data = try StandardInput.readAll(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        // Neither the enter sequence from init nor the leave sequence from deinit: switching
        // buffers on something that is not a terminal only corrupts what reads it.
        #expect(data.isEmpty)
    }
}
