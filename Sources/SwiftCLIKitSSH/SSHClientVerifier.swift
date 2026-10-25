// SSHClientVerifier.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-10-24.

import Foundation

/// Decides, asynchronously, whether a client that has presented a credential is admitted.
///
/// The seam for an identity layer. A synchronous `.password` closure can't call an
/// asynchronous resolver without blocking a thread, and leaves nowhere to put what it
/// resolved; a verifier can do both. An identity layer such as SwiftIdentity fits here: call its
/// `Authenticator` from ``verify(_:)`` and attach the `Authentication` it returns. A roster of
/// keys shows the shape:
///
/// ```swift
/// actor Roster {
///     private let subjects: [String: String]   // OpenSSH key → subject ID
///     init(subjects: [String: String]) { self.subjects = subjects }
///     func subject(for key: String) -> String? { subjects[key] }
/// }
///
/// struct RosterVerifier: SSHClientVerifier {
///     let roster: Roster
///     var methods: SSHVerificationMethods { .publicKey }
///
///     func verify(_ attempt: SSHAuthenticationAttempt) async -> SSHVerdict {
///         guard let key = attempt.evidence.openSSHPublicKey,
///               let subject = await roster.subject(for: key) else { return .refuse }
///         return .admit(attaching: subject)
///     }
/// }
///
/// let verifier = RosterVerifier(roster: Roster(subjects: [:]))
/// let configuration = SSHConfiguration(authMode: .verifier(verifier))
/// ```
///
/// Each connection's attempts arrive one at a time, in order, and count towards
/// ``SSHConfiguration/maxAuthAttempts``; methods outside ``methods`` are refused without a call.
/// The verifier runs on the cooperative pool, not the connection's event loop, so suspending
/// holds up no other connection. CPU-heavy work done without suspending still occupies a pool
/// thread; a KDF that runs for long should run on a thread of its own.
public protocol SSHClientVerifier: Sendable {
    /// The methods clients are offered. Others are refused without calling ``verify(_:)``.
    var methods: SSHVerificationMethods { get }

    /// Decides one attempt.
    /// - Parameter attempt: What the client presented. NIOSSH has already checked a public-key
    ///   attempt's signature, so the client holds the key.
    /// - Returns: Whether to admit, and anything to carry into ``SSHSession/verification``.
    func verify(_ attempt: SSHAuthenticationAttempt) async -> SSHVerdict
}

/// The authentication methods an ``SSHClientVerifier`` accepts.
public struct SSHVerificationMethods: OptionSet, Sendable, Hashable {
    /// The raw bits.
    public let rawValue: UInt8

    /// Creates a set from its raw bits.
    /// - Parameter rawValue: The bits.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Passwords.
    public static let password = SSHVerificationMethods(rawValue: 1 << 0)
    /// Public keys the client has proved it holds.
    public static let publicKey = SSHVerificationMethods(rawValue: 1 << 1)
}

/// One credential a client presented, as an ``SSHClientVerifier`` sees it.
///
/// The password is here, and only here, so the verifier can check it. It is not kept after
/// ``SSHClientVerifier/verify(_:)`` returns, and it never appears in this value's description,
/// debug description or `Mirror`.
public struct SSHAuthenticationAttempt: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// The username the client asked for.
    public let username: String
    /// What was presented: ``SSHClientIdentity/Evidence/password`` or a public key.
    public let evidence: SSHClientIdentity.Evidence
    /// The password, for a password attempt; `nil` otherwise.
    public let password: String?

    /// Creates an attempt.
    /// - Parameters:
    ///   - username: The username the client asked for.
    ///   - evidence: What was presented.
    ///   - password: The password, for a password attempt.
    public init(username: String, evidence: SSHClientIdentity.Evidence, password: String? = nil) {
        self.username = username
        self.evidence = evidence
        self.password = password
    }

    /// The username and the kind of evidence; never the password.
    public var description: String {
        "SSHAuthenticationAttempt(username: \(username), evidence: \(evidence.kind))"
    }

    /// The same as ``description``.
    public var debugDescription: String {
        description
    }

    /// A mirror without the password.
    public var customMirror: Mirror {
        Mirror(self, children: ["username": username, "evidence": evidence.kind], displayStyle: .struct)
    }
}

/// An ``SSHClientVerifier``'s decision.
public struct SSHVerdict: Sendable {
    /// Whether the client is admitted.
    public let admits: Bool
    /// What the verifier attached for the session, if anything.
    public let attachment: (any Sendable)?

    private init(admits: Bool, attachment: (any Sendable)?) {
        self.admits = admits
        self.attachment = attachment
    }

    /// Refuse. The client may try again, up to ``SSHConfiguration/maxAuthAttempts``.
    public static let refuse = SSHVerdict(admits: false, attachment: nil)

    /// Admit, attaching nothing.
    public static let admit = SSHVerdict(admits: true, attachment: nil)

    /// Admit, and carry `value` into every session on the connection as
    /// ``SSHSession/verification`` — for example the identity layer's record of who this is.
    /// - Parameter value: What to attach.
    /// - Returns: An admitting verdict.
    public static func admit(attaching value: any Sendable) -> SSHVerdict {
        SSHVerdict(admits: true, attachment: value)
    }
}
