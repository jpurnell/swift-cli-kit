// SSHSessionTests.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKitSSH
import SwiftCLIKit

@Suite("SSHSession")
struct SSHSessionTests {

    @Test("Session creates with correct fields")
    func sessionCreatesWithCorrectFields() {
        let session = SSHSession(id: "test-123", remoteAddress: "10.0.1.50")
        #expect(session.id == "test-123")
        #expect(session.remoteAddress == "10.0.1.50")
        #expect(session.terminalSize == TerminalSize(columns: 80, rows: 24))
    }

    @Test("Session respects custom terminal size")
    func sessionCustomTerminalSize() {
        let size = TerminalSize(columns: 120, rows: 40)
        let session = SSHSession(id: "test-456", remoteAddress: "10.0.1.51", terminalSize: size)
        #expect(session.terminalSize.columns == 120)
        #expect(session.terminalSize.rows == 40)
    }

    @Test("Session connectedAt is set to approximately now")
    func sessionConnectedAtIsNow() {
        let before = Date()
        let session = SSHSession(id: "test-789", remoteAddress: "10.0.1.52")
        let after = Date()
        #expect(session.connectedAt >= before)
        #expect(session.connectedAt <= after)
    }
}
