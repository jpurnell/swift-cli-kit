// SSHClientIdentity.swift
// SwiftCLIKitSSH
// Created by Justin Purnell on 2026-10-24.

import Foundation
@preconcurrency import NIOSSH

/// Who an ``SSHServer`` admitted on a connection, and what they proved it with.
///
/// Every session on the connection carries the same identity in
/// ``SSHSession/clientIdentity``, so an app can keep its own allow-list, or hand the evidence
/// to an identity layer such as SwiftIdentity:
///
/// ```swift
/// let allowedKeys: Set<String> = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnly"]
/// let server = SSHServer(configuration: SSHConfiguration(authMode: .publicKey))
/// try await server.start { backend, session in
///     guard let key = session.clientIdentity?.evidence.openSSHPublicKey,
///           allowedKeys.contains(key) else {
///         backend.write("Not allowed.\r\n")
///         return
///     }
///     backend.write("Welcome, \(session.clientIdentity?.username ?? "")\r\n")
/// }
/// ```
///
/// The evidence says what was *presented and accepted under the server's
/// ``SSHConfiguration/AuthMode``*. Under ``SSHConfiguration/AuthMode/publicKey`` that is any
/// key the client proved it holds; deciding whether the key belongs to someone the app knows is
/// the app's job. A password is never kept: ``Evidence/password`` records only that one was
/// accepted.
public struct SSHClientIdentity: Sendable, Equatable {
    /// The username the client asked to be admitted as.
    public let username: String
    /// What the client presented.
    public let evidence: Evidence

    /// Creates an identity.
    /// - Parameters:
    ///   - username: The username the client asked for.
    ///   - evidence: What the client presented.
    public init(username: String, evidence: Evidence) {
        self.username = username
        self.evidence = evidence
    }

    /// What a client presented to be admitted.
    ///
    /// A struct with static members rather than an enum, so that kinds can be added (FIDO keys,
    /// if swift-nio-ssh gains them) without breaking a caller's exhaustive `switch`. Compare
    /// ``kind`` to decide what to do.
    public struct Evidence: Sendable, Equatable {
        /// `"none"`, `"password"`, `"public-key"` or `"certificate"`.
        public let kind: String
        /// The client's key in OpenSSH form (`ssh-ed25519 AAAA…`, without a comment), for
        /// `"public-key"` and `"certificate"`; for a certificate, the certificate itself.
        public let openSSHPublicKey: String?
        /// What the certificate says, for `"certificate"`.
        public let certificate: SSHCertificateSummary?

        /// Nothing was presented: the server's mode is ``SSHConfiguration/AuthMode/none``.
        public static let none = Evidence(kind: "none", openSSHPublicKey: nil, certificate: nil)

        /// A password was accepted. The password itself is not kept.
        public static let password = Evidence(kind: "password", openSSHPublicKey: nil, certificate: nil)

        /// The client proved it holds the private half of this key.
        /// - Parameter openSSH: The key in OpenSSH form.
        /// - Returns: Public-key evidence.
        public static func publicKey(openSSH: String) -> Evidence {
            Evidence(kind: "public-key", openSSHPublicKey: openSSH, certificate: nil)
        }

        /// The client proved it holds a certified key.
        ///
        /// The certificate is reported, not trusted: nothing here checks its signing CA, its
        /// validity window or its principals. That is a policy decision for whoever reads it.
        ///
        /// - Important: swift-nio-ssh's server does not yet accept certificate sign-ins. It
        ///   parses user authentication only for plain Ed25519 and ECDSA keys, and refuses a
        ///   certificate before ``SSHServer`` sees it (checked against swift-nio-ssh 0.15.0 and
        ///   its main branch, 2026-10-24). This evidence exists so that certificates arrive
        ///   without an API change once it does.
        ///
        /// - Parameters:
        ///   - summary: What the certificate says.
        ///   - openSSH: The certificate in OpenSSH form.
        /// - Returns: Certificate evidence.
        public static func certificate(_ summary: SSHCertificateSummary, openSSH: String) -> Evidence {
            Evidence(kind: "certificate", openSSHPublicKey: openSSH, certificate: summary)
        }
    }
}

/// The fields of an OpenSSH certificate that decide whom it names, as `ssh-keygen -L` shows them.
///
/// swift-nio-ssh parses the certificate; this is a copy of the parts an admission policy reads.
public struct SSHCertificateSummary: Sendable, Equatable {
    /// The certificate's key ID (`ssh-keygen -I`).
    public let keyID: String
    /// The principals it is valid for (`ssh-keygen -n`), in the certificate's order.
    public let principals: [String]
    /// The start of its validity window.
    public let validAfter: Date
    /// The end of its validity window.
    public let validBefore: Date
    /// The public key of the CA that signed it, in OpenSSH form.
    public let signingCAOpenSSH: String

    /// Creates a summary.
    /// - Parameters:
    ///   - keyID: The key ID.
    ///   - principals: The principals.
    ///   - validAfter: The start of the validity window.
    ///   - validBefore: The end of the validity window.
    ///   - signingCAOpenSSH: The signing CA's public key in OpenSSH form.
    public init(keyID: String, principals: [String], validAfter: Date, validBefore: Date, signingCAOpenSSH: String) {
        self.keyID = keyID
        self.principals = principals
        self.validAfter = validAfter
        self.validBefore = validBefore
        self.signingCAOpenSSH = signingCAOpenSSH
    }
}

extension SSHClientIdentity {
    /// The identity a request establishes once it has been admitted.
    /// - Parameter request: An admitted authentication request.
    init(admitted request: NIOSSHUserAuthenticationRequest) {
        let evidence: Evidence
        switch request.request {
        case .none:
            evidence = .none
        case .password:
            evidence = .password
        case .publicKey(let offered):
            evidence = Evidence(offered.publicKey)
        case .hostBased:
            // Never offered: no mode advertises host-based authentication except `.none`,
            // and that mode admits without looking at evidence.
            evidence = .none
        }
        self.init(username: request.username, evidence: evidence)
    }
}

extension SSHClientIdentity.Evidence {
    /// Evidence for a key NIOSSH has verified: a certificate if it is one, a plain key otherwise.
    init(_ key: NIOSSHPublicKey) {
        let openSSH = String(openSSHPublicKey: key)
        guard let certified = NIOSSHCertifiedPublicKey(key) else {
            self = .publicKey(openSSH: openSSH)
            return
        }
        let summary = SSHCertificateSummary(
            keyID: certified.keyID,
            principals: certified.validPrincipals,
            validAfter: Date(timeIntervalSince1970: TimeInterval(certified.validAfter)),
            validBefore: Date(timeIntervalSince1970: TimeInterval(certified.validBefore)),
            signingCAOpenSSH: String(openSSHPublicKey: certified.signatureKey)
        )
        self = .certificate(summary, openSSH: openSSH)
    }
}
