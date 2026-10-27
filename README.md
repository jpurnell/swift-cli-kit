# SwiftCLIKit

Pure Swift terminal abstraction library -- raw mode, input parsing, line editing, and rendering primitives with zero C dependencies.

> **SwiftGUIKit** — the cross-surface UI kit built on SwiftCLIKit: describe a UI
> once as a semantic scene graph and render it to a terminal *and* native SwiftUI,
> with Apple's HIG as the baseline. See **[Documentation/SwiftGUIKit.md](Documentation/SwiftGUIKit.md)**.

## Requirements

- **Swift 6.2+** — the manifest is `swift-tools-version: 6.2`; earlier toolchains cannot parse it
- macOS 14+, iOS 17+ or visionOS 1+, or Linux

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/swift-cli-kit.git", from: "2.5.0"),
]
```

`jpurnell/swift-cli-kit` is the public repository; each release lands there as one
clean-history commit with its tag. `2.5.0` makes a local terminal's `nextKey()` cancellable and delivers a lone Escape; `2.4.0` adds `SSHServer.listen` (a server you can address and stop) and `ANSICodes.eraseLine`; `2.3.0` lets SSH sessions read keys (`await backend.nextKey()`); `2.2.1` makes `TestBackend.submitRender(_:)` public; `2.2.0` adds `SSHSession.clientIdentity` and
`AuthMode.verifier`; `2.1.0` is the first release whose floor is macOS 14; `2.0.0` needs macOS 15.

Then depend on the products you need — `SwiftCLIKit` for the terminal layer,
`SwiftGUIKit` for the cross-surface scene graph:

```swift
.target(
    name: "MyTool",
    dependencies: [
        .product(name: "SwiftCLIKit", package: "swift-cli-kit"),
    ]
)
```

## Quick Start

```swift
import SwiftCLIKit

let terminal = RawTerminal()
let reader = KeyReader(terminal: terminal)

while let key = reader.readKey() {
    if case .ctrlC = key { break }
    print("Key: \(key)")
}
```

## Serving over SSH

`SwiftCLIKitSSH` serves an app to each SSH connection. Who can reach the server and who it
lets in are both explicit:

```swift
import SwiftCLIKitSSH

let server = SSHServer(
    port: 2222,                                   // host defaults to 127.0.0.1
    configuration: SSHConfiguration(
        authMode: .password { user, password in   // required — there is no default
            user == "admin" && password == "secret"
        }
    )
)
```

Pass `host: "0.0.0.0"` to accept connections from other machines. `authMode: .none` admits
every client and is for development on loopback. Upgrading from 1.x: see the migration table
in [CHANGELOG.md](CHANGELOG.md).

**SSH here is not post-quantum.** swift-nio-ssh negotiates only classical key exchange
(curve25519 and the NIST curves; checked at 0.15.0, 2026-10-24). A session recorded today,
including any password typed into it, could be decrypted by a future quantum computer, and
OpenSSH 10.1+ clients warn about this on every connection. If that matters for your
deployment, put the app behind OpenSSH or behind TLS, both of which already negotiate hybrid
post-quantum key exchange.

A session reads what the client types with `await backend.nextKey()`, which returns `nil` when
the client disconnects.

`session.clientIdentity` says who was admitted and with what: the username and a password, a
public key in OpenSSH form, or nothing. `SSHConfiguration.maxAuthAttempts` (default 6) closes a
connection that keeps guessing, and a `.password` validator runs on a thread pool, so a slow,
strong KDF doesn't stall other connections.

## Documentation

- [SwiftCLIKitGuide.md](SwiftCLIKitGuide.md) — the terminal toolkit.
- [Documentation/SwiftGUIKit.md](Documentation/SwiftGUIKit.md) — the cross-surface UI kit (terminal + SwiftUI).

## License

MIT
