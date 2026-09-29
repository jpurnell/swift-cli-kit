// SessionManagerTests.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKitSSH
import SwiftCLIKit

@Suite("SessionManager")
struct SessionManagerTests {

    @Test("Add session increases count")
    func addSessionIncreasesCount() async {
        let manager = SessionManager(maxConnections: 10)
        let session = SSHSession(id: "s1", remoteAddress: "10.0.1.1")
        let accepted = await manager.addSession(session)
        #expect(accepted == true)
        let count = await manager.activeSessionCount()
        #expect(count == 1)
    }

    @Test("Remove session decreases count")
    func removeSessionDecreasesCount() async {
        let manager = SessionManager(maxConnections: 10)
        let session = SSHSession(id: "s1", remoteAddress: "10.0.1.1")
        _ = await manager.addSession(session)
        await manager.removeSession(id: "s1")
        let count = await manager.activeSessionCount()
        #expect(count == 0)
    }

    @Test("Max connections enforced returns false on overflow")
    func maxConnectionsEnforced() async {
        let manager = SessionManager(maxConnections: 2)
        let s1 = SSHSession(id: "s1", remoteAddress: "10.0.1.1")
        let s2 = SSHSession(id: "s2", remoteAddress: "10.0.1.2")
        let s3 = SSHSession(id: "s3", remoteAddress: "10.0.1.3")
        _ = await manager.addSession(s1)
        _ = await manager.addSession(s2)
        let rejected = await manager.addSession(s3)
        #expect(rejected == false)
        let count = await manager.activeSessionCount()
        #expect(count == 2)
    }

    @Test("allSessions returns added sessions")
    func allSessionsReturnsAdded() async {
        let manager = SessionManager(maxConnections: 10)
        let s1 = SSHSession(id: "s1", remoteAddress: "10.0.1.1")
        let s2 = SSHSession(id: "s2", remoteAddress: "10.0.1.2")
        _ = await manager.addSession(s1)
        _ = await manager.addSession(s2)
        let all = await manager.allSessions()
        let ids = Set(all.map(\.id))
        #expect(ids == Set(["s1", "s2"]))
    }
}
