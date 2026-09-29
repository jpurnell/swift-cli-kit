# Changelog

All notable changes to SwiftCLIKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
