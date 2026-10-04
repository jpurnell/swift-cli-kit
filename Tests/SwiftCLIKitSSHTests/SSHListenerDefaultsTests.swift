// SSHListenerDefaultsTests.swift
// SwiftCLIKitSSH

import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
import Synchronization
@testable import SwiftCLIKitSSH

/// Records the credentials a password validator was shown.
private final class SeenCredentials: Sendable {
    private let state: Mutex<[String]> = Mutex([])

    func record(_ user: String, _ password: String) {
        state.withLock { $0.append("\(user):\(password)") }
    }

    var values: [String] {
        state.withLock { $0 }
    }
}

/// What an `SSHServer` is when nobody says otherwise.
///
/// `SSHServer()` used to be an SSH server on every interface that authenticated nobody:
/// `host` defaulted to `"0.0.0.0"`, `authMode` to `.none`, and `start()` installed an
/// accept-everything delegate without reading `authMode` at all, so even
/// `.password { … }` let every client in.
@Suite("SSH listener defaults")
struct SSHListenerDefaultsTests {

    private static func request(
        _ user: String,
        _ request: NIOSSHUserAuthenticationRequest.Request
    ) -> NIOSSHUserAuthenticationRequest {
        NIOSSHUserAuthenticationRequest(username: user, serviceName: "ssh-connection", request: request)
    }

    private static var publicKeyRequest: NIOSSHUserAuthenticationRequest.Request {
        .publicKey(.init(publicKey: NIOSSHPrivateKey(ed25519Key: .init()).publicKey))
    }

    // MARK: - Bind address

    @Test("A server created without a host is addressed to loopback")
    func defaultHostIsLoopback() {
        let server = SSHServer(configuration: SSHConfiguration(authMode: .publicKey))
        #expect(server.host == "127.0.0.1")
        #expect(SSHServer.loopbackHost == "127.0.0.1")
        #expect(server.port == 2222)
    }

    @Test("A wider bind is kept exactly as the caller wrote it")
    func explicitHostIsKept() {
        let server = SSHServer(host: "0.0.0.0", configuration: SSHConfiguration(authMode: .publicKey))
        #expect(server.host == "0.0.0.0")
    }

    @Test("The socket a default server opens is bound to 127.0.0.1")
    func defaultSocketIsBoundToLoopback() async throws {
        let server = SSHServer(port: 0, configuration: SSHConfiguration(authMode: .publicKey))
        let channel = try await server.bindListener(group: MultiThreadedEventLoopGroup.singleton) { _, _ in }
        let address = channel.localAddress
        try await channel.close()

        #expect(address?.ipAddress == "127.0.0.1")
        #expect(address?.protocol == .inet)
    }

    // MARK: - Configuration

    @Test("A configuration keeps the mode it was given and the documented limits")
    func configurationKeepsMode() {
        let configuration = SSHConfiguration(authMode: .publicKey)
        #expect(configuration.maxConnections == 10)
        #expect(configuration.idleTimeout == .seconds(300))
        #expect(configuration.authMode.authenticatesClients)
    }

    @Test("Only .none authenticates nobody")
    func authenticatesClients() {
        #expect(!SSHConfiguration.AuthMode.none.authenticatesClients)
        #expect(SSHConfiguration.AuthMode.publicKey.authenticatesClients)
        #expect(SSHConfiguration.AuthMode.password { _, _ in false }.authenticatesClients)
    }

    // MARK: - The mode is enforced

    @Test(".none admits every request, and offers every method")
    func noneAdmitsEverything() {
        let authenticator = SSHAuthenticator(mode: .none)
        #expect(authenticator.supportedAuthenticationMethods == .all)
        #expect(authenticator.admits(Self.request("guest", .none)))
        #expect(authenticator.admits(Self.request("guest", .password(.init(password: "anything")))))
        #expect(authenticator.admits(Self.request("guest", Self.publicKeyRequest)))
    }

    @Test(".password admits exactly what its validator admits")
    func passwordIsValidated() {
        let seen = SeenCredentials()
        let authenticator = SSHAuthenticator(mode: .password { user, password in
            seen.record(user, password)
            return user == "admin" && password == "correct horse"
        })

        #expect(authenticator.supportedAuthenticationMethods == .password)
        #expect(authenticator.admits(Self.request("admin", .password(.init(password: "correct horse")))))
        #expect(!authenticator.admits(Self.request("admin", .password(.init(password: "wrong")))))
        #expect(!authenticator.admits(Self.request("guest", .password(.init(password: "correct horse")))))
        #expect(seen.values == ["admin:correct horse", "admin:wrong", "guest:correct horse"])
    }

    @Test(".password refuses a request that carries no password, without asking the validator")
    func passwordRefusesOtherMethods() {
        let seen = SeenCredentials()
        let authenticator = SSHAuthenticator(mode: .password { user, password in
            seen.record(user, password)
            return true
        })

        #expect(!authenticator.admits(Self.request("admin", .none)))
        #expect(!authenticator.admits(Self.request("admin", Self.publicKeyRequest)))
        #expect(seen.values == [])
    }

    @Test(".publicKey admits a key and refuses a password or nothing")
    func publicKeyRefusesOtherMethods() {
        let authenticator = SSHAuthenticator(mode: .publicKey)
        #expect(authenticator.supportedAuthenticationMethods == .publicKey)
        #expect(authenticator.admits(Self.request("anyone", Self.publicKeyRequest)))
        #expect(!authenticator.admits(Self.request("anyone", .password(.init(password: "x")))))
        #expect(!authenticator.admits(Self.request("anyone", .none)))
    }
}
