// SSHHostKeyTests.swift
// SwiftCLIKitSSH

import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
import SwiftCLIKit
@testable import SwiftCLIKitSSH

/// Captures the host key a server presents, then abandons the handshake.
///
/// Completes `presented` exactly once: with the key, or with `nil` if `finish` is called first
/// (the timeout). The lock makes "first one wins" hold whichever thread gets there.
private final class HostKeyRecorder: NIOSSHClientServerAuthenticationDelegate, Sendable {
    private struct Abandon: Error {}

    let presented: EventLoopPromise<NIOSSHPublicKey?>
    private let done = LockedState(false)

    init(promise: EventLoopPromise<NIOSSHPublicKey?>) {
        self.presented = promise
    }

    func finish(_ key: NIOSSHPublicKey?) {
        let first = done.withLock { finished -> Bool in
            guard !finished else { return false }
            finished = true
            return true
        }
        if first { presented.succeed(key) }
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        finish(hostKey)
        validationCompletePromise.fail(Abandon())
    }
}

/// Never offers a credential: the handshake is abandoned at host key validation, before this
/// is asked.
private final class NoUserAuth: NIOSSHClientUserAuthenticationDelegate, Sendable {
    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        nextChallengePromise.succeed(nil)
    }
}

/// `HostKeySource.filePath` used to be accepted and ignored: `bindListener` generated a fresh
/// Ed25519 key whichever source was named, so a server presented a new identity on every start
/// and its clients had no way to tell it from an impersonator.
@Suite("SSH host key")
struct SSHHostKeyTests {

    // MARK: - Fixtures

    /// Copies a fixture to a fresh temporary file with the given mode, and returns its path.
    ///
    /// Git does not keep file modes, so the checked-in fixture cannot carry `0600` itself.
    private static func fixture(_ name: String, mode: Int = 0o600) throws -> String {
        let source = try #require(
            Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"),
            "fixture \(name) is missing from the test bundle"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHHostKeyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: destination.path)
        return destination.path
    }

    /// The public half of the Ed25519 fixture, as `ssh-keygen` wrote it.
    private static func fixturePublicKey() throws -> NIOSSHPublicKey {
        let url = try #require(
            Bundle.module.url(forResource: "host_ed25519", withExtension: "pub", subdirectory: "Fixtures")
        )
        let line = try String(contentsOf: url, encoding: .utf8)
        return try NIOSSHPublicKey(openSSHPublicKey: line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Writes `contents` to a fresh temporary file with mode `0600`.
    private static func temporaryFile(_ contents: String) throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHHostKeyTests-\(UUID().uuidString)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url.path
    }

    /// Connects to a server bound by `bindListener` and returns the host key it presents.
    private static func presentedHostKey(by server: SSHServer) async throws -> NIOSSHPublicKey? {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let listener = try await server.bindListener(group: group) { _, _ in }
        let port = try #require(listener.localAddress?.port)

        let recorder = HostKeyRecorder(promise: group.next().makePromise(of: NIOSSHPublicKey?.self))
        let timeout = group.next().scheduleTask(in: .seconds(10)) { recorder.finish(nil) }

        let client = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        NIOSSHHandler(
                            role: .client(.init(userAuthDelegate: NoUserAuth(), serverAuthDelegate: recorder)),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                }
            }
            .connect(host: "127.0.0.1", port: port)
            .get()

        let key = try await recorder.presented.futureResult.get()
        timeout.cancel()
        try? await client.close()
        try await listener.close()
        try await group.shutdownGracefully()
        return key
    }

    // MARK: - The named key is the key presented

    @Test("A server given .filePath presents that file's key to clients")
    func filePathKeyIsPresented() async throws {
        let server = SSHServer(
            port: 0,
            hostKeySource: .filePath(try Self.fixture("host_ed25519")),
            configuration: SSHConfiguration(authMode: .publicKey)
        )
        let presented = try await Self.presentedHostKey(by: server)
        #expect(presented == (try Self.fixturePublicKey()))
    }

    @Test("Loading the same file twice yields the same key")
    func filePathKeyIsStable() throws {
        let source = SSHServer.HostKeySource.filePath(try Self.fixture("host_ed25519"))
        #expect(try source.privateKey().publicKey == source.privateKey().publicKey)
        #expect(try source.privateKey().publicKey == Self.fixturePublicKey())
    }

    @Test("An ephemeral source yields a different key each time")
    func ephemeralKeysDiffer() throws {
        let source = SSHServer.HostKeySource.generateEphemeral
        #expect(try source.privateKey().publicKey != source.privateKey().publicKey)
    }

    // MARK: - A key that cannot be used stops the server; it never falls back to an ephemeral one

    @Test("A missing file stops the server before it listens")
    func missingFileStopsTheServer() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHHostKeyTests-missing-\(UUID().uuidString)").path
        let server = SSHServer(
            port: 0,
            hostKeySource: .filePath(path),
            configuration: SSHConfiguration(authMode: .publicKey)
        )
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        await #expect(throws: SSHServer.HostKeyError.unreadable(path: path)) {
            _ = try await server.bindListener(group: group) { _, _ in }
        }
        try await group.shutdownGracefully()
    }

    @Test("A key file others can read is refused, as OpenSSH refuses it")
    func openPermissionsAreRefused() throws {
        let path = try Self.fixture("host_ed25519", mode: 0o644)
        #expect(throws: SSHServer.HostKeyError.permissionsTooOpen(path: path, mode: 0o644)) {
            _ = try SSHServer.HostKeySource.filePath(path).privateKey()
        }
    }

    @Test("A file that is not an OpenSSH private key is refused")
    func notAKeyIsRefused() throws {
        let path = try Self.temporaryFile("this is not a key\n")
        #expect(throws: SSHServer.HostKeyError.notOpenSSHPrivateKey(path: path)) {
            _ = try SSHServer.HostKeySource.filePath(path).privateKey()
        }
    }

    @Test("A passphrase-protected key is refused with a reason, not misread")
    func encryptedKeyIsRefused() throws {
        let path = try Self.fixture("host_ed25519_encrypted")
        #expect(throws: SSHServer.HostKeyError.encrypted(path: path)) {
            _ = try SSHServer.HostKeySource.filePath(path).privateKey()
        }
    }

    @Test("A key type the loader does not read is named in the refusal")
    func unsupportedTypeIsNamed() throws {
        let path = try Self.fixture("host_ecdsa")
        #expect(throws: SSHServer.HostKeyError.unsupportedKeyType(path: path, type: "ecdsa-sha2-nistp256")) {
            _ = try SSHServer.HostKeySource.filePath(path).privateKey()
        }
    }

    @Test("A key whose check integers disagree is refused as malformed")
    func corruptedKeyIsRefused() throws {
        // Rebuild the fixture with its second check integer altered. The private section of an
        // unencrypted key starts with two equal uint32s; a reader that skips comparing them
        // would accept a file damaged in exactly the bytes that exist to detect damage.
        let url = try #require(
            Bundle.module.url(forResource: "host_ed25519", withExtension: nil, subdirectory: "Fixtures")
        )
        let armored = try String(contentsOf: url, encoding: .utf8)
        let body = armored.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("-----") }.joined()
        var bytes = try #require(Data(base64Encoded: body))
        let checkIntOffset = try #require(Self.privateSectionOffset(in: bytes)) + 4
        bytes[checkIntOffset] ^= 0xFF
        let rearmored = "-----BEGIN OPENSSH PRIVATE KEY-----\n"
            + bytes.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            + "\n-----END OPENSSH PRIVATE KEY-----\n"
        let path = try Self.temporaryFile(rearmored)

        #expect(throws: SSHServer.HostKeyError.malformed(path: path, detail: "check integers differ")) {
            _ = try SSHServer.HostKeySource.filePath(path).privateKey()
        }
    }

    /// Where the private section's bytes start in a decoded, unencrypted, single-key file:
    /// past the magic, three strings (cipher, KDF, KDF options), the key count, the public key
    /// string, and the private section's own length.
    private static func privateSectionOffset(in bytes: Data) -> Int? {
        var offset = 15   // "openssh-key-v1\0"
        func skipString() -> Bool {
            guard offset + 4 <= bytes.count else { return false }
            let length = bytes[bytes.startIndex + offset ..< bytes.startIndex + offset + 4]
                .reduce(0) { $0 << 8 | Int($1) }
            offset += 4 + length
            return offset <= bytes.count
        }
        guard skipString(), skipString(), skipString() else { return nil }
        offset += 4       // number of keys
        guard skipString() else { return nil }
        offset += 4       // private section length
        return offset + 4 <= bytes.count ? offset : nil
    }
}
