# Changelog

All notable changes to SwiftCLIKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.3.0] - 2026-10-25

SSH sessions read keys. Until now an SSH app could only draw: `SSHBackend.readKey()` was a
placeholder that returned `nil`, and the bytes a client typed were never read.

### Added

- **`TerminalBackend.nextKey() async -> Key?`**: the next key, waiting without blocking a thread
  where the backend can. It's a protocol requirement with a default that calls `readKey()`, so
  every existing conformer compiles unchanged.
- **SSH key input.** `SSHBackend.nextKey()` waits for the client's next key and returns `nil` once
  the channel closes; `readKey()` returns a key that has arrived, or `nil` without waiting.
  - Bytes are decoded as `KeyReader` decodes a terminal's, so a key split across SSH packets
    arrives whole.
  - `SSHBackend.maxQueuedKeys` (4096) bounds the keys held while a session isn't reading; more
    are dropped.
  - `SSHBackend.finishInput()` ends input. The channel handler calls it when the channel goes
    inactive, so a session waiting for a key is released.
  - `SSHBackend.init` gains `maxPasteBytes:` (defaulted).
- **`KeyDecoder`**: `KeyReader`'s decoding, fed a byte at a time (`feed(_:)`, `finish()`,
  `isFinished`), for input pushed to you in pieces. `KeyReader` reads through it, so both paths
  decode identically. Before `KeyReader` moved onto it, it was checked against the old reader
  on every single byte, 60 fixtures, every truncation and every pair of them, and the paste
  budget's exact boundary; five planted mutants were all caught.
- **`TestBackend.nextKey()`, `endInput()` and `isAwaitingKey`**, so code that reads keys can be
  tested headless, injecting a key once the code under test is reading.

### Changed

- **CSI parameters and SGR mouse reports are capped at 64 bytes.** `KeyReader` collected them
  until a final byte with no limit. That was harmless from a local terminal, but over SSH the
  client chooses those bytes. Past the cap, bytes are discarded through the final byte, which
  decodes as `.unknown(0x1B)`.
- `SSHBackend.init` no longer throws. `throws` stays in the signature and
  `SSHBackend.Error.continuationUnavailable` stays in the API, so existing `try` and `catch`
  compile.

### Fixed

- Every byte an SSH client sent was held in an `AsyncStream` nothing read, for the life of the
  session.

### Known limitations

- `RealBackend` uses the default `nextKey()`, which calls the blocking `readKey()` and so holds a
  thread while it waits for the terminal.
- The macOS 26 SDK `SwiftUIRenderer` warnings listed under 2.2.1 remain.
- Post-quantum key exchange moves to 2.4.0.

## [2.2.1] - 2026-10-25

### Fixed

- **`TestBackend.submitRender(_:)` is public.** `renderHistory` and `currentBuffer` were public,
  but the only way to fill them was internal, and nothing in the library called it: its doc
  said the `App` runtime did, and `App` takes no backend. Outside this module a `TestBackend`'s
  render history was always empty. A consumer's test now renders a frame and records it.
  The 2.2.0 gate cleanup dropped the `// LIVE:` marker that had hidden this, and
  quality-gate-swift's newer unreachable check failed the public 2.2.0 CI run on it; the
  locally installed gate predated that check.

### Known limitations

- Built against the macOS 26 SDK (CI's Xcode 26.6), `SwiftUIRenderer.view(for:onAction:)` draws
  four strict-concurrency warnings: it is nonisolated and calls SwiftUI `List` initializers that
  SDK marks `@MainActor`. The macOS 27 SDK doesn't flag these calls. Marking the method
  `@MainActor` would break callers outside the main actor, so it is not done in a patch release.
  These warnings were already present in 2.1.3's CI runs.

## [2.2.0] - 2026-10-24

The sign-in seam: who connected over SSH, an asynchronous verifier for an identity layer, and
the password-path fixes from the sign-in proposal's §3a.

### Added

- **`SSHSession.clientIdentity`**: who the server admitted on the connection, and with what.
  `SSHClientIdentity` holds the username and its `Evidence`: `none`, `password` (recorded as
  accepted, never kept), `publicKey(openSSH:)`, or `certificate(_:openSSH:)` with an
  `SSHCertificateSummary` (key ID, principals, validity window, signing CA). An app can keep its
  own allow-list, or hand the evidence to an identity layer. `Evidence` is a struct with static
  members so kinds can be added without breaking an exhaustive `switch`.
- **`AuthMode.verifier(any SSHClientVerifier)`**, the asynchronous seam for an identity layer.
  A verifier's `verify(_:)` receives an `SSHAuthenticationAttempt` (username, evidence, and the
  password for a password attempt, which is never kept and never appears in the attempt's
  description or `Mirror`), and returns an `SSHVerdict`: `.refuse`, `.admit`, or
  `.admit(attaching:)`, whose value every session on the connection carries as
  `SSHSession.verification`. It runs off the event loop, offers only the
  `SSHVerificationMethods` it names, and its refusals count towards `maxAuthAttempts`. The
  `.password` closure can't call an async resolver such as SwiftIdentity's `Authenticator`
  without blocking a thread, and has nowhere to put what it resolved; this can do both.
- **`SSHConfiguration.maxAuthAttempts`** (default 6, OpenSSH's `MaxAuthTries` default): after
  that many failed password or public-key attempts the server closes the connection, and an
  attempt past the cap is refused without reaching the validator. Attempts are counted as they
  arrive, so parallel requests can't overrun it. The `none` probe doesn't count. This bounds
  guessing per connection; the per-account limit belongs to the identity layer behind the
  validator.
- Each connection now gets its own authenticator, which remembers whom it admitted. Before,
  one was shared by every connection on the server.
- **Bracketed paste.** `KeyReader` recognizes `ESC [ 200 ~` … `ESC [ 201 ~` and returns
  the whole paste as one `Key.paste(String)`. The body is decoded as UTF-8 in one pass, so
  multi-byte characters survive, and newlines, `ESC` and control bytes inside a paste are
  content rather than keys; a paste spanning several reads still arrives whole. Enable it
  with the new `ANSICodes.enableBracketedPaste` (`ESC[?2004h`) and turn it off with
  `ANSICodes.disableBracketedPaste` before restoring the terminal. (Auth proposal §3a fix 3,
  rows P11a/P11b.)
- `KeyReader.init(terminal:maxPasteBytes:)`, `KeyReader.maxPasteBytes` and
  `KeyReader.defaultMaxPasteBytes` (1 MiB). A paste over the cap, or one that is not valid
  UTF-8, is read through its end marker and refused as `.unknown(0x1B)` — never truncated
  and never repaired with U+FFFD. A paste cut off by EOF returns `nil`. The existing
  `KeyReader(terminal:)` call is unchanged.
- **`SecureField`**, a single-line input for passwords and other secrets, with
  `SecureFieldResult`. Each character renders as `mask` (default `•`; `nil` draws nothing)
  until revealed — `toggleReveal()`, `setRevealed(_:)`, or a caller-bound `revealKey`
  (P12). Editing works on whole `Character`s, widths come from `UnicodeWidth`, there is no
  length cap and nothing is truncated (P7), and a `Key.paste` is inserted whole (P11a/b).
  `SecureFieldResult` carries no text. `description`, `debugDescription`, `Mirror` and
  `dump` show neither the secret nor its length; `consume()` returns the value and empties
  the field, `clear()` discards it.
- `LineEditor` (and so `TextField`) inserts a `Key.paste` at the cursor, and `TextArea` inserts
  it whole across lines: CR, LF and CRLF in a paste all become line breaks, since terminals
  usually send a pasted newline as CR.

### Changed

- **Source-level: `SSHConfiguration.AuthMode` has a new case, `.verifier`.** A `switch` over
  `AuthMode` with no `default:` stops compiling until it handles it, as with `Key.paste`
  below. Both are cases callers rarely switch over; SemVer would put them in a major release,
  and this release takes the 2.x line's precedent of adding enum cases in a minor one.
- **swift-nio-ssh 0.15.0 is the minimum** (was 0.9.0; 0.13.0 was resolved). 0.14.0 fixes a crash
  on a bare LF as the client's first byte, 0.14.1 rejects oversized ECDSA signature integers, and
  0.15.0 bounds buffered state and the number of authentication messages a client may send.
- **Source-level: `Key` has a new case, `.paste(String)`.** `Key` is a public enum and the
  package does not build with library evolution, so a `switch` over `Key` with no
  `default:` stops compiling until it handles `.paste`. Every switch in
  this package already had a `default:`; add one, or a `.paste` case, to yours. Binary and
  behaviour are otherwise unchanged: a terminal sends paste markers only after
  `enableBracketedPaste` is written.
- `TextField` and `SecureField` share one internal drawing routine for the label and box.
  `TextField` content now draws into a clipped area, so wide text can no longer overwrite
  the box's right border, and the box starts after the label's display width rather than
  its `Character` count (they differ only for wide labels, such as CJK).

### Fixed

- The guide's key-reading example matched `.f(let n)`, which doesn't exist; it's
  `.functionKey(let n)`.
- **A password validator no longer runs on the connection's event loop.** It ran inline, so a
  validator using a strong KDF (600,000-round PBKDF2, Argon2id) stalled every other connection
  that loop served for as long as it worked, which pushed callers towards weak ones. It now runs
  on `NIOThreadPool.singleton`, and NIOSSH is answered when it finishes. The `.password` closure's
  signature is unchanged. If the pool can't take the work, the attempt is refused.

### Known limitations

- **SSH key exchange is not post-quantum**, and the docs now say so (`SSHServer`, README, guide).
  swift-nio-ssh offers only classical key exchange and doesn't let one be added (0.15.0); a
  recorded session could be decrypted later, passwords included. Put the app behind OpenSSH or
  TLS where that matters. Post-quantum key exchange is planned for 2.3.0.
- **SSH certificates can't be used to sign in yet.** swift-nio-ssh's server parses user
  authentication only for plain Ed25519 and ECDSA keys and refuses a certificate before
  SwiftCLIKit sees it (0.15.0 and main, checked 2026-10-24). Certificate evidence is in the API
  so it arrives without a change once upstream accepts them; a test pins today's refusal.

### Quality

- **The quality gate's unvalidated suppressions are gone: 43 → 0 suppressed, 21 → 0
  baselined, 3 → 0 config overrides.** What remains is 6 acknowledgements whose reasons the gate
  validates (`// Justification:`, `// SAFETY:`, `// silent:`).
- **Floating-point values no longer trap when converted to `Int`.** The 21 baselined findings
  were real crashes reachable from public API with a NaN, an infinity or a value past `Int`'s
  range: `TerminalFormatter.formatNumber` in a narrow column, `Formatting.duration` /
  `elapsed` / `rate`, `GaugeGeometry`, `SparklineGeometry`, `InlineSparkline` and
  `BarChartRenderer` given a NaN point, a bar labelled with a NaN or infinite value, and the
  dashboard's pass-rate percentage. A NaN point now draws empty, a duration is capped at
  9e18 s, and a value with no short form is written as Swift writes it (`nan`, `inf`,
  `1e+300`). Output for finite, in-range values is unchanged.
- **Failures that `try?` discarded are now logged** (os.Logger, privacy-annotated): a snapshot
  golden file that can't be written, a session record that can't be decoded or encoded.
  `ANSIStringMetrics` strips escapes with a scanner rather than an `NSRegularExpression`, so
  there is no `try?` left there; it removes exactly what the regex did.
- **34 `// LIVE:` markers removed.** 32 hid nothing; the other two hid dead internal code
  (`Color.nearestANSI8`, `CSSSyntaxTokenizer.atRules`), now deleted.
- **The examples target is audited by everything except one rule.** Its unguarded
  conversions, unseeded randomness (the generator is now injected from `@main`), silent
  `catch`/`try?` and dead members are fixed. It stays in `excludePatterns` only because its
  `print()` calls are terminal output and `logging.print-statement` has no per-target CLI
  mode.


## [2.1.3] - 2026-10-20

A security fix, released as a patch. It adds one public type, `SSHServer.HostKeyError`, which
SemVer would place in a minor release; it ships here because the fix should not wait for
2.2.0, and the type exists only to report the fix's refusals.

### Security

- **`HostKeySource.filePath` is enforced.** `SSHServer` generated a fresh Ed25519 host key on
  every start whichever source was named, so a server presented a new identity each time it
  restarted. Its clients could not tell it from an impersonator, and users learned to accept
  the changed-key warning that exists to catch one — the opening a machine-in-the-middle needs
  to collect the passwords sent to the server. `.filePath` now loads the named key: an
  unencrypted Ed25519 key in OpenSSH's format, as `ssh-keygen -t ed25519 -N ""` writes it.

### Changed

- **A host key file that cannot be used stops the server.** `start` throws the new
  `SSHServer.HostKeyError` before listening when the file is missing or unreadable, readable
  by other users (OpenSSH's rule; `chmod 600` it), passphrase-protected, of a type other than
  `ssh-ed25519`, or internally inconsistent. Code that passed `.filePath` with a path that
  did not hold a usable key used to start with an ephemeral key; it now fails, which is the
  point — there is no fallback.
- **A server bound beyond loopback with `.generateEphemeral` logs a warning** at startup,
  as one with `authMode: .none` already does.
- `SwiftCLIKitSSH` names `swift-crypto` in the manifest, to build a key from the file. It was
  already resolved and linked through `swift-nio-ssh`; nothing new is downloaded.

## [2.1.2] - 2026-10-20

No public API changes.

### Fixed

- **A progress bar with a NaN ratio no longer stops the process.** `ProgressBarLayout`
  clamped `current / total` with `min(max(_, 0), 1)`, which does not remove NaN, then
  converted it with `Int(ratio * 100)`, which traps on NaN. A NaN `current`, or an
  infinite `current` over an infinite `total`, crashed `ProgressBar.render` and
  SwiftGUIKit's `CellRenderer`. Those inputs now resolve to the zero-total fallback —
  no bar, and `"0%"` when a percentage is shown. Found by the `fallback` rule in
  quality-gate `d7b2bbf`; the 3.5.0 binary used locally did not report it.
- **The Quality Gate workflow reaches the corpus over the deploy key.** It passed
  `corpus-token: ${{ secrets.CORPUS_PUSH_TOKEN }}`, an input the reusable workflow has
  deprecated, and the public repository had no secret by that name, so the corpus
  checkout failed with "no corpus credential was supplied". It now passes
  `corpus-deploy-key: ${{ secrets.CORPUS_DEPLOY_KEY }}`, as every other caller does.

## [2.1.1] - 2026-10-20

No code changes.

### Fixed

- **The Quality Gate workflow starts again.** It granted `permissions: contents: read`,
  but the reusable workflow it calls in `jpurnell/quality-gate-swift` requests
  `issues: write`. A called workflow cannot hold more than its caller grants, so GitHub
  rejected every run with `startup_failure` before any job began. The caller now grants
  `contents: read` and `issues: write`. The reusable workflow is referenced at `@main`,
  so a future permission it adds will break the caller the same way.
- **The install snippets name the public repository, and it resolves.** The README and
  `SwiftCLIKitGuide.md` name `github.com/jpurnell/swift-cli-kit.git` with
  `from: "2.1.0"` and `.product(name: "SwiftCLIKit", package: "swift-cli-kit")` — the
  package identity follows the URL, so the guide's bare `"SwiftCLIKit"` dependency is
  now an explicit product reference.

  This reverses an unreleased change made on 2026-10-09, which pointed both snippets
  at the private `jpurnell/SwiftCLIKit` because the public repository held only v1.4.1
  and v1.4.2. That was true when it was written and stopped being true the same
  afternoon, when v2.0.0 and v2.1.0 were exported to the public repository. A public
  README naming a repository its readers cannot open was the wrong fix to keep.
- `SwiftCLIKitGuide.md` paired `platforms: [.macOS(.v14)]` with `from: "1.0.0"`, which
  resolves to 1.4.0 — a release whose floor is macOS 15. It says `from: "2.1.0"`.

## [2.1.0] - 2026-10-06

A minor after 2.0.0 — a lower floor takes nothing away from
anyone already on macOS 15, and no public API changes.

### Changed

- **The platform floor is macOS 14 and iOS 17**, down from macOS 15 and iOS 18. The
  deployment host is capped at macOS 14.8.9, and a binary built against the old floor did
  not fail to compile for it — it failed to launch on it:
  `dyld: Library not loaded: /usr/lib/swift/libswiftSynchronization.dylib`. Every package
  that depends on this one inherited the floor, so the server binaries downstream could not
  be deployed at all.
- **visionOS 1 is declared.** It was the implicit floor already and every library target
  builds for it; the manifest now says so.
- **`Synchronization` is no longer imported anywhere.** `Mutex` was the only thing keeping
  the libraries on macOS 15. Its ten uses across nine files in `SwiftCLIKit` and `SwiftCLIKitSSH` now go
  through one package-internal type, `LockedState`, which is `OSAllocatedUnfairLock` on
  Apple platforms (macOS 13, iOS 16) and a `pthread_mutex_t` elsewhere. On Apple platforms
  that is the same `os_unfair_lock` `Mutex` wrapped, so locking behaviour is unchanged,
  including that it is not recursive. `BufferRef`, `RawTerminal`, `AlternateScreen`,
  `StatusArea`, `TestBackend`, `RealBackend`, `SSHBackend`, `ResizeToken` and
  `SnapshotTesting` are `Sendable` exactly as before, with no `@unchecked`.
- `swiftclikit-examples` now depends on `swift-atomics` for the one `Atomic<Bool>` it used
  — the flag its SIGINT handler raises. That stays an atomic rather than becoming a lock
  because a signal handler that takes a lock the interrupted thread already holds traps.
  `swift-atomics` was already in the graph through `swift-nio`; no library product links
  it, and `Package.resolved` is unchanged.

### Added

- A test that reads the declared macOS floor from `Package.swift` and fails if any file
  under `Sources/` imports `Synchronization` while that floor is below 15. The compiler
  only catches this when building for the lower target, which a newer development machine
  does not do by default.

### Not changed

- tvOS and watchOS remain undeclared. `SwiftCLIKit`, `SwiftCLIKitSSH`, `SwiftGUIKit` and
  `QualityGateDashboard` build for tvOS 17 and watchOS 10; `SwiftGUIKitSwiftUI` does not,
  because it uses SwiftUI views those platforms do not have (`OutlineGroup`, `TextEditor`,
  segmented pickers). That is a porting job, not a floor.
- The non-Apple `LockedState` path is exercised on macOS by building with
  `-DSWIFTCLIKIT_PTHREAD_LOCK`; it has not been built on Linux, which has no CI here.

## [2.0.0] - 2026-10-03

A major version, because `SSHServer()` and `SSHConfiguration()` no longer compile. That is
the point: both used to produce an SSH server on every interface that authenticated nobody,
and neither said so. Only `SwiftCLIKitSSH` breaks; `SwiftCLIKit`, `SwiftGUIKit` and the
dashboard targets are source-compatible with 1.4.0.

### Security — breaking

- **`SSHServer` bound every interface by default.** `host` defaulted to `"0.0.0.0"`. It now
  defaults to `SSHServer.loopbackHost` (`"127.0.0.1"`); a wider bind is an argument somebody
  wrote. The startup log reports the address the channel is bound to rather than the one
  requested.
- **`SSHConfiguration.authMode` defaulted to `.none`.** It is now a required argument of
  `SSHConfiguration.init(maxConnections:idleTimeout:authMode:)`, and `SSHServer.init`'s
  `configuration` is required with it. `.none` still exists; it has to be written.
- **`authMode` was never enforced.** `SSHServer.start` installed a delegate that accepted
  every request and did not read `configuration.authMode`, so a server configured with
  `.password { … }` or `.publicKey` admitted every client, validator uncalled. The mode is
  now what decides: `.password` admits a password its validator accepts and nothing else,
  `.publicKey` admits a public-key request and nothing else, `.none` admits everything.
  Only the methods a mode can admit are offered to the client. A server in `.none` logs a
  warning when it starts.

### Added

- `SSHServer.loopbackHost`.
- `SSHConfiguration.AuthMode.authenticatesClients` — `false` only for `.none`.

### Migration from 1.x

| 1.x | 2.0 |
|---|---|
| `SSHConfiguration()` | `SSHConfiguration(authMode: .none)` — the same behaviour, now stated. Prefer `.password { … }` or `.publicKey`. |
| `SSHConfiguration(maxConnections: 32)` | `SSHConfiguration(maxConnections: 32, authMode: …)` |
| `SSHServer()` / `SSHServer(port: 2222)` | `SSHServer(port: 2222, configuration: SSHConfiguration(authMode: …))` |
| relied on the server being reachable from other machines | add `host: "0.0.0.0"` (or a specific interface address) |

Two behaviour changes need no source edit and are easy to miss:

- A call that already passed `authMode: .password { … }` or `.publicKey` compiled against 1.x
  and was **not** being authenticated. Under 2.0 it is. Clients that connected with no
  credential, or the wrong one, are now refused.
- A call that passed no `host` now listens on loopback only.

Still not enforced, and unchanged by this release: `maxConnections`, `idleTimeout`, and
`HostKeySource.filePath` (an ephemeral key is generated whichever source is named).

### Changed

- The session-replay test sandbox checks containment by path components; its `deinit` would
  otherwise have removed any directory whose path began with the sandbox root's.


### Changed

- Four `// SECURITY:` acknowledgements now say what was decided, ahead of the quality gate requiring a
  reason of at least eight words on every one.

### Fixed
- **`TerminalFormatter.formatDate` named the wrong year when it fell back to year-only.** The
  medium and short styles were formatted in the requested locale, but the last-resort year came
  from `Calendar.current` — the calendar of whatever machine ran it. Asking for
  `ja_JP@calendar=japanese` at width 2 returned `19` (a truncated Gregorian `1970`) instead of
  `45` (Shōwa 45). The fallback now uses the requested locale's calendar and the formatter's
  time zone, so all three widths describe the same date.

### Changed
- `SessionReplayTests` and `LocalizationTests` moved from XCTest to Swift Testing, the last two
  files that had not. `SessionRecorderTests` keeps its per-test sandbox directory through
  `init`/`deinit`, and creating it now fails the test instead of being swallowed by `try?`.
  Snapshot counts are `#require`d before the snapshots are indexed.

## [1.4.0] - 2026-09-17

Cut, rather than moving a tag again. `v1.3.1` has pointed at three different revisions —
`d15c8819`, then `c11bc235`, then `b69bf73c` — and `d15c8819` is now reachable from no ref at
all. SwiftPM records the revision it first saw for a version in a machine-global
trust-on-first-use database and refuses a later mismatch, so every consumer that had ever
resolved `1.3.1` was blocked, on every machine, with no defect in either package.

The rule that follows: a published version tag is immutable. Correcting a release means
publishing the next one, because the alternative is per-machine surgery on a security database
that exists precisely to notice what was done.

The release also takes the package to 0 errors / 0 warnings, which it was not when the tag
moved.

### Fixed
- **Two focus assertions asserted nothing when they mattered most.**
  `#expect(current == nil || fm.focusOrder.contains(current ?? ""))` passes when `focused` is
  nil — which is the failure the test was written to catch — and the `?? ""` fallback asserts a
  missing value as if it were present. The test's setup is fully determined: a retained index
  of 1 into a shrunk `["a", "c"]` is `"c"`, and `focusNext` from there wraps to `"a"`. Both are
  now asserted by value, which is what the disjunction was hiding.
- Three `TextField` fixtures were `var` without ever being mutated. The two that *do* call a
  mutating member stay `var` — the compiler distinguishes them, so the reader does not have to.
- **The three time-formatting tests could return past their own fixture.** Each opened
  with two `guard ... else { return }` binds — `TimeZone(identifier: "UTC")` and
  `Calendar.date(from:)` — which the `test-quality` checker reports as
  `unasserted-optional-unwrap`. Neither can return nil for a fully specified Gregorian
  component set, so nothing was in fact being guarded against; had either done so, the
  test would have reported success having asserted nothing. Both binds move into one
  `utcInstant(hour:minute:second:)` helper built on `try #require`, which also collapses
  a fixture that was triplicated across the three tests down to a single definition.
- **Every `## Usage` example compiles.** 50 `doc-comment-code` errors across 36
  files — the largest count in the fleet — surfaced when that checker briefly
  entered the default set upstream. They had been wrong for as long as they
  existed.

  Thirteen were one template: every widget's example called
  `render(into: &frame)` without a frame. One binding, applied thirteen times.

  The framework examples referenced model and message types a *consumer* defines
  — `MyModel`, `CounterModel`, `Msg` — so each fence now declares the small types
  it needs, which documents what you have to supply. `App` and `Component` also
  needed their generic parameters spelled out; with the model and message types
  only appearing inside closures, `Message` could not be inferred.

  Three were documented APIs that do not exist as written: `Frame(bufferRef:)` is
  internal, so the example used an initialiser a caller cannot call; `PixelData`'s
  initialiser is failable and three fences treated it as if it were not; and
  `SSHBackend`'s is throwing.

  Two fences used a literal `...` as a stand-in for omitted values, which Swift
  parses as an operator applied to nothing.

### Added
- `StandardInput` — bounded reads of a piped payload, with an explicit byte ceiling and
  `EINTR` retry, for CLIs that take their input on stdin.
- Inline gauge and sparkline widgets
- Formatting utilities (elapsed, duration, bytes, time, rate)
- Accessibility `reduceMotion` support in animations
- `SSHBackend(isInteractive:)` — non-interactive `exec` sessions (no PTY) now
  suppress cursor/screen-control escapes, the SSH analog of an `isatty` check,
  so captured output stays clean.
- `SSHSessionRequestState` — folds a session's SSH channel requests
  (`pty-req`, `window-change`, `shell`, `exec`) into interactivity, terminal
  size, and requested program. `isInteractive` tracks PTY allocation exactly, so
  `ssh -tt host cmd` is interactive while `ssh -T host` is not.
- `SSHServer` now spawns a per-connection session channel handler (previously the
  child-channel initializer was a stub): it threads negotiated PTY state into
  `SSHBackend(isInteractive:)`, forwards inbound channel bytes to the backend's
  input stream, writes backend output back to the SSH channel, and invokes the
  server's session handler for `shell`/`exec` requests.

### Fixed
- **`AlternateScreen` no longer corrupts redirected output.** It wrote `ESC[?1049h` on
  init and `ESC[?1049l` on deinit unconditionally, straight to the file descriptor. Piped
  or redirected, those bytes arrive as literal escape text in whatever reads the output.
  Switching buffers is now a no-op on a non-terminal descriptor, `isActive` reports it, and
  `deinit` only restores a screen this instance actually switched. `init` takes an
  `isTerminal` predicate defaulting to `isatty` — supplied by tests driving a pipe, and by
  callers that have already resolved the question. Source-compatible: every existing call
  site uses the default.
- `StandardInput.readAll(fileDescriptor:limit:)` replaces `readDataToEndOfFile()` in
  `qg-dashboard` and `QGDashboardApp`. Reading a pipe to EOF is bounded in neither time nor
  memory: a writer that stays open parks the process, one that never stops exhausts it.
  Reads now come in 64 KiB chunks against an explicit ceiling (8 MiB default), retry
  `EINTR`, and surface `errno`.
- `HexColor.toANSI8` kept its channels integral. They are bytes, and `max`/`min` return an
  argument unchanged, so `maxC == r` was an exact comparison of exact values wearing a
  float-equality question it never needed to ask.
- DiffRenderer color bleed after render
- Path traversal hardening in SnapshotTesting, SessionPlayer, SessionRecorder
- Floating-point safety in PerfTracker FPS calculation
- Quality-gate cleanup: `qg-dashboard` / `QGDashboardApp` route output to
  stdout/stderr and log load failures via `os.Logger` instead of `print()`;
  guard-driven base cases added to tree/measure recursion; SwiftGUIKit's public
  design vocabulary (appearance/surface/unit enums) marked as reachable API.

## [1.3.1] - 2026-07-13

### Fixed
- SwiftGUIKit renders `.table` as a non-scrolling stack rather than a `List`,
  so tables lay out at their intrinsic height on the native surface.

## [1.3.0] - 2026-07-12

### Added
- **SwiftGUIKit** — a cross-surface UI kit layered on SwiftCLIKit: semantic
  design tokens resolved per surface by a `TokenResolver` (terminal, SwiftUI),
  a full widget catalog ported as `Node`s with terminal↔native parity, container
  nodes (stacks, padding, Block), intrinsic sizing (`measure` + `SizeConstraint.fit`),
  and resolvers that honor density, pointer, and high-contrast appearance.
- **QualityGateDashboard** — one scene rendered to two surfaces (terminal and
  SwiftUI), including the IJS portfolio and per-project detail scenes.
- **QGDashboardApp** — a native SwiftUI window for the gate dashboard, with
  `--watch` auto-refresh and a headless `--render` PNG mode for CI.
- **qg-dashboard** — a runnable terminal executable for the gate dashboard.

## [1.2.0] - 2026-07-04

### Added
- `ANSIStringMetrics.elideMiddle(_:to:)` — middle elision that keeps both the
  leading text and the trailing camel-case suffix, joined by a horizontal
  ellipsis (`BioFeedbackKit` → `BioFee…Kit`). It deliberately favors preserving a
  whole trailing suffix (`Kit`, `UI`, `BASIC`) over an even split, so sibling
  module names stay distinguishable in tight columns (`HarborKit` → `Ha…Kit`,
  `HarborUI` → `Har…UI`). Width-aware (never splits a wide grapheme), ANSI-safe
  (interior escapes stripped), and returns the input unchanged when it already
  fits — giving callers an `elideMiddle(s, to: w) != s` "was this elided?" signal
  for gating a hover tooltip. TDD, 12 tests.

## [1.1.0] - 2026-07-04

### Added
- `MouseCapture` — a small state helper that tracks terminal mouse reporting and
  vends the correct enable/disable sequences, so an event loop can pause capture
  for native text selection (no Shift needed) and resume it.
- `TextReflow` — rejoins hard-wrapped terminal lines into logical, copy-ready
  text (`unwrap(_:)`, `unwrap(rendered:)`), so full-screen output can be copied
  without a newline at every wrap point.
- `ANSIStringMetrics.plainText(_:)` — public ANSI-escape stripping for extracting
  copy-ready text from rendered output.
- `Paragraph` source retention — `logicalLines`, `wrappedLines(width:)`, and
  `sourceLineMap(width:)` expose the pre-wrap text and the visual-to-source line
  mapping, enabling faithful OSC 52 copy of a rendered paragraph's true content.

### Fixed
- Guard `import os` behind `#if canImport(os)` in `Clipboard` and `SSHServer`
  (with the associated `Logger` usage) for clean cross-platform/Linux builds.

## [1.0.1] - 2025-05-15

### Fixed
- DocC symbol references for SessionPlayerError, ASCIIArt, and cross-module refs
- Floating-point safety false positives (inline non-zero literal divisors)
- Doc-lint scope limited to SwiftCLIKit target

## [1.14.0] - 2025-05-12

### Added
- Backtab (Shift-Tab) key support (CSI Z)

### Fixed
- Color.default uses .defaultColor case with SGR 39/49

## [1.12.0] - 2025-05-08

### Added
- Embedded SSH server module (SwiftCLIKitSSH)

## [1.0.0] - 2025-04-10

### Added
- Two-layer terminal abstraction (Terminal + UI)
- Cell-based rendering with CellBuffer and DiffRenderer
- Widget library: Table, List, Tree, Gauge, ProgressBar, Sparkline, BarChart, Tabs, Menu, Scrollbar, CalendarView, Block, Paragraph
- Layout system with Rect, Layout, Frame
- App/Cmd/Subscription framework with EventStream
- Input handling: Key, KeyReader, LineEditor, InputHistory, MouseEvent
- Alternate screen, cursor control, raw terminal mode
- ANSI color negotiation (truecolor, 256-color, 16-color)
- Unicode width support and ANSI string metrics
- FocusManager and Component protocol
- Snapshot testing support
- Session recording and playback
- Performance tracking
- Accessibility labels, roles, and announcements
