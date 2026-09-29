// SSHBackendTests.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
import Synchronization
@testable import SwiftCLIKitSSH
import SwiftCLIKit

/// Thread-safe accumulator for captured output strings.
private final class CapturedOutput: Sendable {
    private let state: Mutex<[String]> = Mutex([])

    func append(_ string: String) {
        state.withLock { $0.append(string) }
    }

    var values: [String] {
        state.withLock { $0 }
    }
}

@Suite("SSHBackend")
struct SSHBackendTests {

    @Test("Write calls output handler with correct string")
    func writeCallsOutputHandler() throws {
        let captured = CapturedOutput()
        let backend = try SSHBackend(outputHandler: { captured.append($0) })
        backend.write("Hello SSH")
        #expect(captured.values == ["Hello SSH"])
    }

    @Test("UpdateSize changes terminalSize")
    func updateSizeChangesTerminalSize() throws {
        let noop: @Sendable (String) -> Void = { _ in }
        let backend = try SSHBackend(outputHandler: noop)
        #expect(backend.terminalSize() == TerminalSize(columns: 80, rows: 24))
        backend.updateSize(TerminalSize(columns: 120, rows: 40))
        #expect(backend.terminalSize() == TerminalSize(columns: 120, rows: 40))
    }

    @Test("enableRawMode does not throw for SSH backend")
    func enableRawModeNoOp() throws {
        let noop: @Sendable (String) -> Void = { _ in }
        let backend = try SSHBackend(outputHandler: noop)
        try backend.enableRawMode()
        // Verify SSH backend is still functional after enableRawMode (no-op for SSH)
        #expect(backend.terminalSize() == TerminalSize(columns: 80, rows: 24))
    }
}
