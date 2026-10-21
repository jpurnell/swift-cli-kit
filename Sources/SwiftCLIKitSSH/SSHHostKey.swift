// SSHHostKey.swift
// SwiftCLIKitSSH
//
// Loading the server's host key. A server that presents a new key on every start cannot be told
// apart from an impersonator, and its users learn to accept the warning that would have caught
// one — so a key file that cannot be used stops the server rather than falling back to an
// ephemeral key.

import Foundation
import Crypto
@preconcurrency import NIOSSH

extension SSHServer {
    /// Why a host key file could not be used.
    ///
    /// Thrown by ``SSHServer/start(sessionHandler:)`` before the server listens. There is no
    /// fallback to an ephemeral key: a server that was told which key to present, and presents
    /// another, is the failure this error exists to prevent.
    public enum HostKeyError: Error, Equatable, Sendable {
        /// The file does not exist or could not be read.
        case unreadable(path: String)
        /// The file's mode lets someone other than its owner read or write it.
        ///
        /// OpenSSH refuses such a key for the same reason: a host key that others can read is
        /// a host key others can present. `chmod 600` the file.
        case permissionsTooOpen(path: String, mode: Int)
        /// The file is not an OpenSSH private key.
        case notOpenSSHPrivateKey(path: String)
        /// The key is protected by a passphrase, which a server starting unattended cannot enter.
        ///
        /// Host keys are conventionally stored without one and protected by file mode instead;
        /// `ssh-keygen -p -N "" -f <path>` removes it.
        case encrypted(path: String)
        /// The key is of a type this loader does not read. Only `ssh-ed25519` is read.
        case unsupportedKeyType(path: String, type: String)
        /// The file claims to be an OpenSSH private key but its contents are inconsistent.
        case malformed(path: String, detail: String)
    }
}

extension SSHServer.HostKeySource {
    /// The private key this source names.
    ///
    /// - Returns: A fresh Ed25519 key for ``generateEphemeral``; the file's key for
    ///   ``filePath(_:)``.
    /// - Throws: ``SSHServer/HostKeyError`` when the file cannot be used.
    func privateKey() throws -> NIOSSHPrivateKey {
        switch self {
        case .generateEphemeral:
            return NIOSSHPrivateKey(ed25519Key: .init())
        case .filePath(let path):
            return try OpenSSHHostKeyFile(path: path).load()
        }
    }
}

/// Reads an unencrypted Ed25519 key in OpenSSH's own format — what `ssh-keygen -t ed25519`
/// writes. The format is specified in OpenSSH's `PROTOCOL.key`.
struct OpenSSHHostKeyFile {
    /// The file to read.
    let path: String

    private static let beginMarker = "-----BEGIN OPENSSH PRIVATE KEY-----"
    private static let endMarker = "-----END OPENSSH PRIVATE KEY-----"
    private static let magic = Array("openssh-key-v1\u{0}".utf8)
    private static let ed25519 = "ssh-ed25519"
    /// An Ed25519 key file is about 400 bytes. Anything far larger is not one, and is not read.
    private static let maximumFileSize = 64 * 1024

    /// Loads the key, checking the file's mode, armor, structure and internal consistency.
    /// - Returns: The key.
    /// - Throws: ``SSHServer/HostKeyError`` for the first check the file fails.
    func load() throws -> NIOSSHPrivateKey {
        let data = try readOwnerOnlyFile()

        guard let text = String(data: data, encoding: .utf8) else {
            throw SSHServer.HostKeyError.notOpenSSHPrivateKey(path: path)
        }
        let armored = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard armored.hasPrefix(Self.beginMarker), armored.hasSuffix(Self.endMarker) else {
            throw SSHServer.HostKeyError.notOpenSSHPrivateKey(path: path)
        }
        let body = armored.split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        guard let decoded = Data(base64Encoded: body) else {
            throw malformed("its body is not base64")
        }

        var reader = SSHWireReader(Array(decoded))
        guard reader.consume(Self.magic) else {
            throw SSHServer.HostKeyError.notOpenSSHPrivateKey(path: path)
        }
        let cipher = try field(reader.string())
        let kdf = try field(reader.string())
        _ = try field(reader.bytes())   // KDF options: empty when unencrypted
        guard cipher == "none", kdf == "none" else {
            throw SSHServer.HostKeyError.encrypted(path: path)
        }
        let keyCount = try field(reader.uint32())
        guard keyCount == 1 else {
            throw malformed("it holds \(keyCount) keys, not one")
        }

        // The public key comes first and unencrypted, so the type is known before the private
        // section is read.
        var publicBlob = SSHWireReader(try field(reader.bytes()))
        let publicType = try field(publicBlob.string())
        guard publicType == Self.ed25519 else {
            throw SSHServer.HostKeyError.unsupportedKeyType(path: path, type: publicType)
        }
        let publicKey = try field(publicBlob.bytes())

        var section = SSHWireReader(try field(reader.bytes()))
        guard reader.isAtEnd else { throw malformed("bytes follow the private section") }

        // Two equal integers open the private section; for an encrypted key, they are how a
        // wrong passphrase is detected, and for any key, how damage is.
        let checkOne = try field(section.uint32())
        let checkTwo = try field(section.uint32())
        guard checkOne == checkTwo else { throw malformed("check integers differ") }

        let privateType = try field(section.string())
        guard privateType == Self.ed25519 else {
            throw malformed("its public key is \(publicType) but its private key is \(privateType)")
        }
        let privatePublicKey = try field(section.bytes())
        // Ed25519's private field is the 32-byte seed followed by the 32-byte public key.
        let secret = try field(section.bytes())
        _ = try field(section.string())   // comment
        guard section.remainingIsPadding() else { throw malformed("its padding is not 1, 2, 3, …") }

        guard publicKey.count == 32, privatePublicKey == publicKey,
              secret.count == 64, Array(secret[32...]) == publicKey else {
            throw malformed("its key fields have the wrong lengths or disagree")
        }
        let signingKey: Curve25519.Signing.PrivateKey
        do {
            signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: secret[..<32])
        } catch {
            throw malformed("its private key is not a valid Ed25519 seed")
        }
        guard Array(signingKey.publicKey.rawRepresentation) == publicKey else {
            throw malformed("its private key does not produce its public key")
        }
        return NIOSSHPrivateKey(ed25519Key: signingKey)
    }

    /// The file's bytes, once its mode shows that only its owner can read or write it.
    private func readOwnerOnlyFile() throws -> Data {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            throw SSHServer.HostKeyError.unreadable(path: path)
        }
        guard let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue,
              let size = (attributes[.size] as? NSNumber)?.intValue else {
            throw SSHServer.HostKeyError.unreadable(path: path)
        }
        guard mode & 0o077 == 0 else {
            throw SSHServer.HostKeyError.permissionsTooOpen(path: path, mode: mode & 0o777)
        }
        guard size <= Self.maximumFileSize else {
            throw malformed("it is \(size) bytes, larger than any key file")
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw SSHServer.HostKeyError.unreadable(path: path)
        }
        return data
    }

    /// A field the reader returned, or a "truncated" refusal when it ran out of bytes.
    private func field<T>(_ value: T?) throws -> T {
        guard let value else { throw malformed("it ends part-way through a field") }
        return value
    }

    private func malformed(_ detail: String) -> SSHServer.HostKeyError {
        .malformed(path: path, detail: detail)
    }
}

/// Reads SSH wire encoding (RFC 4251 §5): big-endian `uint32`s, and strings as a `uint32`
/// length followed by that many bytes. Every read is bounds-checked and returns `nil` rather
/// than reading past the end.
struct SSHWireReader {
    private let buffer: [UInt8]
    private var offset = 0

    init(_ bytes: [UInt8]) {
        self.buffer = bytes
    }

    /// Whether every byte has been read.
    var isAtEnd: Bool { offset == buffer.count }

    /// Consumes `expected` if the bytes at the current position match it.
    mutating func consume(_ expected: [UInt8]) -> Bool {
        guard buffer.count - offset >= expected.count,
              Array(buffer[offset ..< offset + expected.count]) == expected else { return false }
        offset += expected.count
        return true
    }

    /// Reads a big-endian `uint32`.
    mutating func uint32() -> UInt32? {
        guard buffer.count - offset >= 4 else { return nil }
        let value = buffer[offset ..< offset + 4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        offset += 4
        return value
    }

    /// Reads a length-prefixed byte string.
    mutating func bytes() -> [UInt8]? {
        let start = offset
        guard let length = uint32(), UInt64(length) <= UInt64(buffer.count - offset) else {
            offset = start
            return nil
        }
        let count = Int(length)
        let value = Array(buffer[offset ..< offset + count])
        offset += count
        return value
    }

    /// Reads a length-prefixed string as UTF-8.
    mutating func string() -> String? {
        guard let value = bytes() else { return nil }
        return String(bytes: value, encoding: .utf8)
    }

    /// Whether the unread bytes are OpenSSH's deterministic padding: 1, 2, 3, … — and fewer
    /// than a cipher block, which is 8 bytes for an unencrypted key.
    func remainingIsPadding() -> Bool {
        let padding = buffer[offset...]
        guard padding.count < 8 else { return false }
        return padding.enumerated().allSatisfy { Int($0.element) == $0.offset + 1 }
    }
}
