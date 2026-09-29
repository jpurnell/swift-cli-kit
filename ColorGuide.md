# SwiftCLIKit Color and Terminal Guide

This guide covers the color system, mouse input, alternate screen, and cursor
control APIs introduced in SwiftCLIKit v0.2.0.

## Color capability levels

`ColorCapability` describes what a terminal can render. The four levels form an
ordered hierarchy:

| Level        | Raw value | What it means                                    |
|--------------|-----------|--------------------------------------------------|
| `.none`      | 0         | No color output. The `NO_COLOR` env var is set.  |
| `.basic`     | 1         | 8/16 standard ANSI colors (SGR 30-37 / 90-97).   |
| `.extended`  | 2         | 256-color xterm palette (SGR 38;5;n).             |
| `.truecolor` | 3         | Full 24-bit RGB (SGR 38;2;r;g;b).                |

`ColorCapability` conforms to `Comparable`, so you can write guards like
`capability >= .extended`.

## Using the Color type

`Color` unifies three fidelity levels under one `Sendable`, `Equatable`,
`Hashable` enum:

```swift
let red   = Color.ansi8(.red)
let teal  = Color.ansi256(30)
let exact = Color.truecolor(r: 100, g: 149, b: 237)
```

### Hex parsing

`Color.fromHex` accepts CSS-style hex strings with or without the `#` prefix,
and supports 3-digit shorthand:

```swift
let orange = Color.fromHex("#FF8800")   // .truecolor(r: 255, g: 136, b: 0)
let short  = Color.fromHex("F80")       // same result
let bad    = Color.fromHex("nope")      // nil
```

### Equality

Two colors are equal when their cases and associated values match. A
`.truecolor(r: 0, g: 0, b: 128)` is not equal to `.ansi8(.blue)` even though
they look similar on screen.

## Auto-negotiation

`ColorNegotiation.detect()` reads environment variables to determine the best
color capability the current terminal supports:

```swift
let cap = ColorNegotiation.detect()
// Checks NO_COLOR, COLORTERM, and TERM in that order.
```

The detection logic:

1. `NO_COLOR` is set (any value) -- returns `.none`.
2. `COLORTERM` equals `"truecolor"` or `"24bit"` -- returns `.truecolor`.
3. `TERM` contains `"256color"` -- returns `.extended`.
4. `TERM` equals `"dumb"` -- returns `.none`.
5. Otherwise -- returns `.basic`.

Once you have a capability, use the escape helpers to produce ready-to-print
strings:

```swift
let cap = ColorNegotiation.detect()
let fg  = ColorNegotiation.fgEscape(.truecolor(r: 255, g: 136, b: 0), capability: cap)
let bg  = ColorNegotiation.bgEscape(.ansi8(.blue), capability: cap)
print("\(fg)\(bg)Hello\(ANSICodes.reset)")
```

## Downsampling

When you specify a truecolor value but the terminal only supports 256 colors (or
8 colors), `downsampled(to:)` finds the nearest match:

```swift
let coral = Color.truecolor(r: 255, g: 127, b: 80)

// On a 256-color terminal:
let ds256 = coral.downsampled(to: .extended)
// ds256 is .ansi256(209) -- the closest palette entry

// On a basic 8/16-color terminal:
let ds8 = coral.downsampled(to: .basic)
// ds8 is .ansi8(.red) -- the nearest hue bucket

// On a no-color terminal:
let dsNone = coral.downsampled(to: .none)
// dsNone is .ansi8(.black) -- color is suppressed
```

Downsampling is idempotent: calling `.downsampled(to: .truecolor)` on any color
returns the same color unchanged. Downsampling an `.ansi8` to `.extended` also
returns it unchanged, since ANSI-8 is a subset of xterm-256.

You normally do not need to call `downsampled` yourself.
`ColorNegotiation.fgEscape` and `bgEscape` call it automatically.

## Mouse events

Mouse input uses the SGR extended protocol. The lifecycle is enable, parse,
disable.

### Enable

Write the enable sequence to stdout before entering your input loop:

```swift
print(MouseMode.enable, terminator: "")
```

This sends `CSI ?1000h` (enable basic mouse) followed by `CSI ?1006h` (switch to
SGR encoding).

### Parse

When your `KeyReader` encounters the `CSI <` prefix, collect bytes through the
final `M` or `m` and pass them to `MouseMode.parse`:

```swift
// sgrBytes includes the '<', digits, ';' separators, and trailing 'M' or 'm'
if let event = MouseMode.parse(sgrBytes) {
    print("Button: \(event.button), row: \(event.row), col: \(event.column)")
    if event.modifiers.contains(.shift) {
        print("Shift was held")
    }
}
```

`MouseEvent` contains:

- `button` -- `.left`, `.middle`, `.right`, `.scrollUp`, `.scrollDown`, or `.release`
- `column` / `row` -- 1-based terminal coordinates
- `modifiers` -- an `OptionSet` of `.shift`, `.alt`, `.ctrl`

In the `Key` enum, mouse events appear as `.mouse(MouseEvent)`.

### Disable

Restore normal terminal input before exiting:

```swift
print(MouseMode.disable, terminator: "")
```

## Alternate screen

`AlternateScreen` uses RAII: creating an instance enters the alternate buffer,
and deallocation restores the original screen.

```swift
func runFullscreenApp() {
    let screen = AlternateScreen()
    // screen.isActive == true
    print(CursorControl.hide)

    // ... draw your UI ...

    // When `screen` goes out of scope the original terminal content reappears.
}
```

You can also pass a specific file descriptor:

```swift
let screen = AlternateScreen(fileDescriptor: STDERR_FILENO)
```

## Cursor control

`CursorControl` provides static escape strings and functions:

```swift
// Hide cursor during rendering
print(CursorControl.hide, terminator: "")

// Move to row 5, column 10
print(CursorControl.moveTo(row: 5, column: 10), terminator: "")
print("Hello")

// Save and restore position
print(CursorControl.save, terminator: "")
print(CursorControl.moveTo(row: 1, column: 1), terminator: "")
print("Status bar text")
print(CursorControl.restore, terminator: "")

// Relative movement
print(CursorControl.moveUp(3), terminator: "")
print(CursorControl.moveRight(10), terminator: "")

// Change cursor shape
print(CursorControl.setShape(.bar, blinking: true), terminator: "")

// Show cursor again when done
print(CursorControl.show, terminator: "")
```

Available shapes: `.block`, `.underline`, `.bar`. Each can optionally blink.

## Migration from v0.1.0

### HexColor.toColor replaces toANSI8 for new code

In v0.1.0 the only hex conversion was `HexColor.toANSI8(_:)`, which mapped a hex
string to the nearest `ANSIColor`. This still works and is not deprecated.

For new code, prefer the richer pipeline:

```swift
// v0.1.0 style (still works)
if let ansi = HexColor.toANSI8("#FF8800") {
    print(ANSICodes.fg(ansi))
}

// v0.2.0 style -- preserves full fidelity, auto-downsamples
if let color = HexColor.toColor("#FF8800") {
    let cap = ColorNegotiation.detect()
    print(ColorNegotiation.fgEscape(color, capability: cap))
}

// Or use the one-liner shortcut
let escape = HexColor.toEscape("#FF8800", capability: .truecolor)
```

### New Key cases

The `Key` enum now includes `.mouse(MouseEvent)`, `.functionKey(Int)`,
`.pageUp`, `.pageDown`, and `.insert`. If you have exhaustive switches over
`Key`, add handlers for these cases.

### New ANSICodes members

v0.2.0 adds `fg256`, `bg256`, `fgRGB`, `bgRGB`, `strikethrough`, `overline`,
`underlineCurly`, `underlineDouble`, and `underlineDotted`. These are used
internally by `ColorNegotiation` but are also available for direct use.
