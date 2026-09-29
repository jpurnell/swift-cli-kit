// TerminalBackendTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("TerminalBackend")
struct TerminalBackendTests {

    @Test("RealBackend creates without crash")
    func realBackendCreates() {
        let backend = RealBackend()
        // Verify backend is usable after creation
        let size = backend.terminalSize()
        #expect(size.columns >= 0)
    }

    @Test("RealBackend terminalSize returns non-zero dimensions")
    func realBackendTerminalSize() {
        let backend = RealBackend()
        let size = backend.terminalSize()
        #expect(size.columns > 0)
        #expect(size.rows > 0)
    }

    @Test("TestBackend conforms to TerminalBackend protocol")
    func testBackendConformsToProtocol() {
        let backend: any TerminalBackend = TestBackend(width: 80, height: 24)
        let size = backend.terminalSize()
        #expect(size.columns == 80)
        #expect(size.rows == 24)
    }

    @Test("TestBackend write records output for inspection")
    func testBackendWriteRecords() {
        let backend = TestBackend(width: 80, height: 24)
        backend.write("Hello, World")
        #expect(backend.allWrittenOutput == ["Hello, World"])
    }
}
