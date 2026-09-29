# SwiftCLIKit Guide

SwiftCLIKit is a pure Swift terminal UI library. It provides two layers of
abstraction — a low-level terminal foundation and a high-level cell-based UI
framework — plus an embedded SSH server module, all with zero C dependencies
beyond the system libc already linked by Swift.

> **API Reference.** Every public type and method has DocC documentation (100%
> coverage). Generate it with `swift package generate-documentation` or browse
> inline in Xcode. This guide focuses on architecture, patterns, and examples;
> consult DocC for exhaustive parameter details.

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Architecture Overview](#architecture-overview)
3. [Quick Start](#quick-start)
4. [Layer 1: Terminal Foundation](#layer-1-terminal-foundation)
5. [Layer 2: Cell-Based UI](#layer-2-cell-based-ui)
6. [The Elm Architecture Framework](#the-elm-architecture-framework)
7. [Widgets](#widgets)
8. [Animation](#animation)
9. [Theming and Syntax Highlighting](#theming-and-syntax-highlighting)
10. [Image Support](#image-support)
11. [Accessibility](#accessibility)
12. [Formatting Utilities](#formatting-utilities)
13. [Debug and Testing](#debug-and-testing)
14. [SSH Module](#ssh-module)
15. [Platform Support](#platform-support)
16. [Integration](#integration)

---

## Design Philosophy

- **RAII safety.** `RawTerminal` and `AlternateScreen` restore terminal state in
  `deinit`. You cannot forget to clean up.
- **Value types first.** Widgets, layouts, animations, and buffers are structs.
  Mutating methods make state changes explicit at the call site.
- **Swift 6 strict concurrency.** Every public type is `Sendable`. The few
  reference types (`RawTerminal`, `StatusArea`, `AlternateScreen`, `TestBackend`,
  `SSHBackend`) use `@unchecked Sendable` with lock-based synchronization and
  documented justifications.
- **Zero C dependencies.** The library depends only on Foundation and
  Darwin/Glibc. No AppKit, UIKit, or SwiftUI. The SSH module additionally
  depends on swift-nio-ssh.
- **Elm architecture.** The framework layer uses a unidirectional data flow
  pattern: `Model` + `update` + `view`, with `Cmd` for async effects and
  `Subscription` for long-lived event sources.

---

## Architecture Overview

```
SwiftCLIKit
├── Layer 1 — Terminal Foundation (v0.1.0–v0.2.0)
│   ├── Terminal/    RawTerminal, AlternateScreen, CursorControl, TerminalSize, TerminalSettings
│   ├── Input/       Key, KeyReader, LineEditor, InputHistory, MouseEvent, MouseMode
│   ├── Rendering/   ANSICodes, Color, ColorNegotiation, ScreenBuffer, BoxDrawing, StatusArea
│   ├── Clipboard/   Clipboard (OSC 52)
│   └── Util/        UnicodeWidth, ANSIStringMetrics, HexColor, Formatting
│
├── Layer 2 — Cell-Based UI (v0.3.0+)
│   ├── Cell/        Cell, CellAttributes, CellBuffer, BufferRef
│   ├── Layout/      Rect, Layout, Frame
│   ├── Rendering/   DiffRenderer
│   ├── Widgets/     Table, List, Tree, Gauge, ProgressBar, Sparkline, BarChart,
│   │                Tabs, Menu, Scrollbar, CalendarView, Block, Paragraph,
│   │                TextField, Form, Toast, NotificationManager, CommandPalette,
│   │                InlineGauge, InlineSparkline, CellStyle
│   ├── Framework/   App, Cmd, Subscription, EventStream, Event, FocusManager, Component
│   ├── Animation/   Animation, Easing, Transition, AnimatedValue
│   ├── Theme/       Theme, ThemeLoader, ColorCodable
│   ├── SyntaxHighlighting/  SyntaxHighlighter, SyntaxTheme, TokenType, SyntaxLanguage
│   ├── Image/       PixelData, InlineImage, ASCIIArt, KittyEncoder, SixelEncoder, ITermEncoder
│   ├── Accessibility/  AccessibilitySettings, AccessibilityRole, AccessibilityLabel,
│   │                   AccessibleWidget, AccessibilityAnnouncer
│   └── Debug/       PerfTracker, SessionRecorder, SessionPlayer
│
├── Testing/         SnapshotTesting, TestBackend
│
└── SwiftCLIKitSSH   SSHServer, SSHBackend, SSHConfiguration, SSHSession, SessionManager
```

---

## Quick Start

A minimal program that enters raw mode, reads keystrokes, and exits on Ctrl-C:

```swift
import SwiftCLIKit

let terminal = RawTerminal()
let reader = KeyReader(terminal: terminal)

print("Press keys (Ctrl-C to exit):")

while let key = reader.readKey() {
    switch key {
    case .ctrlC:
        print("\nGoodbye!")
        exit(0)
    case .character(let ch):
        print("You pressed: \(ch)")
    default:
        print("Key: \(key)")
    }
}
```

A cell-based UI program using the Elm architecture:

```swift
import SwiftCLIKit

struct Model: Sendable {
    var count = 0
}

enum Message: Sendable {
    case increment
    case decrement
    case quit
}

let app = App(
    initialModel: Model(),
    update: { model, msg in
        switch msg {
        case .increment: model.count += 1
        case .decrement: model.count -= 1
        case .quit: return [.quit]
        }
        return []
    },
    view: { model in
        { frame in
            let text = "Count: \(model.count)  [↑/↓ to change, q to quit]"
            frame.writeText(text, x: 1, y: 1)
        }
    },
    mapEvent: { event in
        switch event {
        case .key(.arrowUp): return .increment
        case .key(.arrowDown): return .decrement
        case .key(.character("q")): return .quit
        default: return nil
        }
    }
)

try await app.run()
```

---

## Layer 1: Terminal Foundation

### Raw Terminal

`RawTerminal` enters raw mode on init and restores the original termios settings
on deinit. If stdin is not a terminal (e.g. a pipe), raw mode is silently
skipped.

```swift
let terminal = RawTerminal()
// Terminal is now in raw mode
// When `terminal` is deallocated, original settings are restored
```

### Alternate Screen

`AlternateScreen` switches to the terminal's alternate buffer (like vim, less).
It restores the primary buffer on deinit.

```swift
do {
    let screen = AlternateScreen()
    // Primary screen content is preserved; you now have a blank canvas
    // ... render your UI ...
}
// Primary screen is restored when `screen` goes out of scope
```

### Key Reading and Input

`KeyReader` parses raw bytes into a `Key` enum covering characters, arrows,
function keys, ctrl-combos, and escape sequences.

```swift
let reader = KeyReader(terminal: terminal)

while let key = reader.readKey() {
    switch key {
    case .character(let ch):  print("Character: \(ch)")
    case .arrowUp:            print("Up arrow")
    case .ctrlC:              break
    case .enter:              print("Enter")
    case .backspace:          print("Backspace")
    case .tab:                print("Tab")
    case .backtab:            print("Shift-Tab")
    case .f(let n):           print("F\(n)")
    default:                  print("\(key)")
    }
}
```

### Mouse Events

Enable SGR extended mouse tracking and parse mouse events:

```swift
print(MouseMode.enable, terminator: "")

// MouseEvent has button, column, row, and modifiers
if let mouse = MouseMode.parse(bytes) {
    switch mouse.button {
    case .left:      print("Click at (\(mouse.column), \(mouse.row))")
    case .scrollUp:  print("Scroll up")
    case .scrollDown: print("Scroll down")
    default: break
    }
    if mouse.modifiers.contains(.shift) {
        print("  with Shift held")
    }
}

print(MouseMode.disable, terminator: "")
```

### Line Editing

`LineEditor` is a value-type single-line editor with cursor movement, kill/yank,
and word operations. Pair it with `InputHistory` for up/down navigation.

```swift
var editor = LineEditor()
var history = InputHistory()

let result = editor.handleKey(key)
switch result {
case .completed(let line):
    history.add(line)
    editor = LineEditor()
case .editing:
    break
case .eof, .interrupt:
    break
}
```

| Key           | Action                          |
|---------------|---------------------------------|
| Printable     | Insert at cursor                |
| Backspace     | Delete before cursor            |
| Delete        | Delete at cursor                |
| Left / Right  | Move cursor                     |
| Home / Ctrl-A | Start of line                   |
| End / Ctrl-E  | End of line                     |
| Ctrl-K        | Kill to end                     |
| Ctrl-U        | Kill to start                   |
| Ctrl-W        | Delete word before cursor       |
| Ctrl-D        | Delete at cursor / EOF if empty |

### Screen Rendering

`ScreenBuffer` builds frame strings for flicker-free rendering. `BoxDrawing`
provides Unicode and ASCII box-drawing character sets.

```swift
let size = TerminalSize.current()
let box = BoxDrawing.unicode
var buffer = ScreenBuffer(width: size.columns)

buffer.appendLine(box.topBorder(" Status ", width: size.columns))
buffer.appendLine(
    box.vertical
    + ANSIStringMetrics.padVisible(" All systems go", to: size.columns - 2)
    + box.vertical
)
buffer.appendLine(box.bottomBorder(width: size.columns))

print(buffer.frame, terminator: "")
fflush(stdout)
```

### Color and Color Negotiation

`Color` supports four fidelity levels. `ColorNegotiation` detects capability
and produces escape sequences.

```swift
let capability = ColorNegotiation.detect()  // .none, .basic, .extended, .truecolor

let red = Color.truecolor(r: 255, g: 0, b: 0)
let downsampled = red.downsampled(to: capability)  // safe for this terminal

let fg = ColorNegotiation.fgEscape(red, capability: capability)
let bg = ColorNegotiation.bgEscape(.ansi256(27), capability: capability)
print(fg + bg + "Styled text" + ANSICodes.reset)

// Parse CSS hex colors
if let color = Color.fromHex("#FF5733") {
    print(ColorNegotiation.fgEscape(color, capability: .truecolor))
}
```

### Cursor Control

```swift
print(CursorControl.hide, terminator: "")
print(CursorControl.moveTo(row: 5, column: 10), terminator: "")
print(CursorControl.setShape(.bar, blinking: true), terminator: "")
// ... render ...
print(CursorControl.show, terminator: "")
```

### Terminal Size and Resize

```swift
let size = TerminalSize.current()  // ioctl query, 80x24 fallback
print("Terminal is \(size.columns) x \(size.rows)")

let token = TerminalSize.onResize { newSize in
    print("Resized to \(newSize.columns)x\(newSize.rows)")
}
// Callback fires on SIGWINCH; deregisters when token is deallocated
```

### Terminal Settings

Persistent per-application configuration stored at
`$XDG_CONFIG_HOME/<appName>/terminal.json`:

```swift
var settings = TerminalSettings.load(appName: "myapp")
let useColor = settings.resolveColor()  // checks NO_COLOR, isatty

settings.colorMode = .always
settings.asciiOnly = true
try settings.save(appName: "myapp")
```

### Unicode Width and ANSI Metrics

```swift
UnicodeWidth.displayWidth("Hello")          // 5
UnicodeWidth.displayWidth("Hello\u{4E16}")  // 7 (CJK character = 2 columns)
UnicodeWidth.width(of: Character("\u{0301}"))  // 0 (combining accent)

let styled = ANSICodes.bold + "Error" + ANSICodes.reset
ANSIStringMetrics.visibleLength(styled)  // 5, not 13
ANSIStringMetrics.padVisible(styled, to: 20)
ANSIStringMetrics.truncateVisible(styled, to: 40)
```

### Clipboard

Terminal clipboard access via OSC 52:

```swift
Clipboard.write("Hello from SwiftCLIKit")

let sequence = Clipboard.writeSequence("Copy this")  // raw escape string
```

### Status Area

Thread-safe scrolling message buffer:

```swift
let status = StatusArea(maxMessages: 3)
status.push("Connected")
status.push("Loading...")
status.push("Ready")

let lines = status.render(width: 80, colorize: true)
```

---

## Layer 2: Cell-Based UI

### Cell and CellBuffer

A `Cell` holds a character, foreground/background colors, and text attributes.
`CellBuffer` is a 2D grid of cells representing the screen.

```swift
let cell = Cell(
    character: "X",
    fg: .truecolor(r: 255, g: 100, b: 0),
    bg: .default,
    attributes: [.bold, .underline]
)

var buffer = CellBuffer(width: 80, height: 24)
buffer[10, 5] = cell
buffer.writeText("Hello", at: (x: 0, y: 0), fg: .ansi8(.green))
buffer.fill(Rect(x: 0, y: 23, width: 80, height: 1), with: Cell(character: " ", fg: .default, bg: .ansi8(.blue)))
buffer.clear()
```

`CellAttributes` is an `OptionSet`: `.bold`, `.dim`, `.italic`, `.underline`,
`.blink`, `.reverse`, `.strikethrough`.

### Layout

`Rect` defines a rectangular region. `Layout` splits areas according to
constraints. `Frame` is a rendering surface backed by a shared buffer and scoped
to a rect.

```swift
let area = Rect(x: 0, y: 0, width: 80, height: 24)

// Split vertically: 3 rows header, flexible body, 1 row footer
let chunks = Layout.split(
    area: area,
    direction: .vertical,
    constraints: [.fixed(3), .percentage(100), .fixed(1)]
)
let header = chunks[0]  // Rect(x: 0, y: 0, width: 80, height: 3)
let body   = chunks[1]  // Rect(x: 0, y: 3, width: 80, height: 20)
let footer = chunks[2]  // Rect(x: 0, y: 23, width: 80, height: 1)

// Split body horizontally: 50/50
let columns = Layout.split(
    area: body,
    direction: .horizontal,
    constraints: [.percentage(50), .percentage(50)]
)
```

Constraints: `.fixed(Int)`, `.percentage(UInt16)`, `.min(Int)`, `.max(Int)`,
`.ratio(Int, Int)`.

### Frame

Widgets render into `Frame`, which clips writes to its rect and shares an
underlying buffer.

```swift
let buf = CellBuffer(width: 80, height: 24)
var frame = Frame(buffer: buf, rect: area)

frame.writeText("Title", x: 1, y: 0, fg: .ansi8(.white), attributes: [.bold])

// Sub-frames for nested rendering
var bodyFrame = frame.subFrame(body)
myWidget.render(into: &bodyFrame)
```

### DiffRenderer

Produces minimal ANSI escape sequences for the delta between frames:

```swift
var renderer = DiffRenderer()
let previous = lastBuffer
let current = frame.cellBuffer
let ansi = renderer.render(current: current, previous: previous)
print(ansi, terminator: "")
fflush(stdout)
```

### CellStyle

Composite style combining color and attributes, used throughout the widget system:

```swift
let highlight = CellStyle(fg: .ansi8(.black), bg: .ansi8(.yellow), attributes: [.bold])
let muted = CellStyle(attributes: [.dim])
```

---

## The Elm Architecture Framework

SwiftCLIKit uses an Elm-inspired unidirectional architecture.

### App

`App<Model, Message>` is the top-level runtime. You provide:
- `initialModel` — your application state
- `update` — a pure function `(inout Model, Message) -> [Cmd<Message>]`
- `view` — renders model into a frame
- `subscriptions` (optional) — long-lived event sources
- `mapEvent` (optional) — converts raw terminal events to messages

```swift
let app = App(
    initialModel: MyModel(),
    update: { model, msg in
        // Handle message, mutate model, return commands
        return []
    },
    view: { model in
        { frame in
            // Render model into frame
        }
    },
    subscriptions: { model in
        [.timer(key: "tick", every: .seconds(1), message: .tick)]
    },
    mapEvent: { event in
        // Convert Event -> Message?
    }
)
try await app.run()
```

### Cmd

Commands describe async side effects returned from `update`:

```swift
// No-op
Cmd.none

// Async work
Cmd.task { await fetchData() }

// Async throwing with error handler
Cmd.task(perform: { try await riskyWork() }, onError: { .failed($0) })

// Batch multiple commands
Cmd.batch([.task { await a() }, .task { await b() }])

// Delayed message
Cmd.delay(.seconds(2), then: .timeout)

// Quit the app
Cmd.quit
```

### Subscription

Subscriptions produce messages over time. They're keyed for lifecycle management
— identical keys are deduplicated, removed keys are cancelled.

```swift
Subscription.timer(key: "clock", every: .seconds(1), message: .tick)

Subscription.stream(key: "data") { send in
    for await item in dataStream {
        send(.dataReceived(item))
    }
}

Subscription.none
```

### Event and EventStream

`Event` covers all terminal input: `.key(Key)`, `.mouse(MouseEvent)`,
`.resize(width:height:)`, `.custom(any Sendable)`.

`EventStream` is an `AsyncSequence` of events:

```swift
let stream = EventStream(terminal: terminal)
for await event in stream {
    switch event {
    case .key(let key): handleKey(key)
    case .mouse(let mouse): handleMouse(mouse)
    case .resize(let w, let h): handleResize(w, h)
    case .custom(let payload): handleCustom(payload)
    }
}
```

### FocusManager

Manages keyboard focus across named UI elements:

```swift
var focus = FocusManager(focusOrder: ["name", "email", "submit"])
focus.focusNext()        // "name"
focus.focusNext()        // "email"
focus.isFocused("email") // true
focus.focusPrevious()    // wraps to "name"
focus.blur()             // no focus
```

### Component

Self-contained UI component for composition:

```swift
let counter = Component(
    initialModel: 0,
    update: { count, msg in
        switch msg {
        case .inc: count += 1
        case .dec: count -= 1
        }
        return []
    },
    view: { count in
        { frame in frame.writeText("Count: \(count)", x: 0, y: 0) }
    },
    toParent: { childMsg in .counterEvent(childMsg) }
)
```

---

## Widgets

All widgets follow a consistent pattern: struct with public init, mutable
properties, and `func render(into frame: inout Frame)`. All are `Sendable`.

### Data Display

#### Table

```swift
let columns: [Table<User>.Column] = [
    .init(header: "Name", width: .percentage(40)) { $0.name },
    .init(header: "Email", width: .percentage(40)) { $0.email },
    .init(header: "Role", width: .percentage(20)) { $0.role },
]

var table = Table(
    columns: columns,
    rows: users,
    state: TableState(selectedRow: 0),
    showScrollbar: true
)
table.render(into: &frame)

// Navigation
table.state.selectNext(rowCount: users.count, visibleRows: 20)
table.state.selectPrevious()
```

#### List

```swift
var list = List(
    items: [
        List.Item(text: "First item"),
        List.Item(text: "Second item", style: CellStyle(fg: .ansi8(.green))),
    ],
    state: ListState(selectedIndex: 0),
    highlightStyle: CellStyle(attributes: [.reverse])
)
list.render(into: &frame)
```

#### Tree

```swift
let root = Tree<String>.TreeNode(value: "src", children: [
    .init(value: "main.swift"),
    .init(value: "lib", children: [
        .init(value: "parser.swift"),
        .init(value: "lexer.swift"),
    ]),
])

var tree = Tree(
    roots: [root],
    state: TreeState(expandedNodes: [root.id]),
    renderNode: { $0 },
    indentWidth: 2
)
tree.render(into: &frame)
tree.state.toggle(nodeID)  // expand/collapse
```

### Visualization

#### Gauge

```swift
var gauge = Gauge(
    ratio: 0.75,
    label: "CPU",
    filledChar: "█",
    unfilledChar: "░"
)
gauge.render(into: &frame)
```

#### ProgressBar

```swift
var progress = ProgressBar(current: 42, total: 100, showPercentage: true)
progress.render(into: &frame)
```

#### Sparkline

```swift
var sparkline = Sparkline(
    data: [1.0, 3.0, 7.0, 2.0, 5.0, 8.0, 4.0],
    style: CellStyle(fg: .ansi8(.cyan))
)
sparkline.render(into: &frame)
```

#### BarChart

```swift
var chart = BarChart(
    bars: [
        .init(label: "Mon", value: 10, style: CellStyle(fg: .ansi8(.blue))),
        .init(label: "Tue", value: 25),
        .init(label: "Wed", value: 18),
    ],
    barWidth: 5,
    showValues: true
)
chart.render(into: &frame)
```

#### InlineGauge and InlineSparkline

ANSI-string widgets for use with `ScreenBuffer` (Layer 1) rather than `Frame`:

```swift
let gaugeStr = InlineGauge.render(current: 75, total: 100, width: 20,
    filledColor: .ansi8(.green))

let sparkStr = InlineSparkline.render(data: [1.0, 3.0, 7.0, 2.0], width: 10,
    color: .ansi8(.cyan))

var buf = ScreenBuffer(width: 80)
buf.append(gaugeStr)
buf.append("  ")
buf.append(sparkStr)
```

### Navigation

#### Tabs

```swift
var tabs = Tabs(
    titles: ["Overview", "Details", "Settings"],
    activeIndex: 0,
    separator: " | "
)
tabs.render(into: &frame)
```

#### Menu

```swift
var menu = Menu(items: [
    .init(label: "New File", keyHint: "Ctrl-N"),
    .init(label: "Open...", keyHint: "Ctrl-O"),
    .init(label: "Save", keyHint: "Ctrl-S", enabled: false),
])
menu.render(into: &frame)
```

#### Scrollbar

```swift
var scrollbar = Scrollbar(
    orientation: .vertical,
    contentLength: 200,
    viewportSize: 24,
    offset: currentScroll
)
scrollbar.render(into: &frame)
```

### Input

#### TextField

```swift
var field = TextField(label: "Name:", placeholder: "Enter your name")
field.render(into: &frame, focused: true)

let result = field.handleKey(key)
switch result {
case .changed(let text): print("Text: \(text)")
case .submitted(let text): print("Submitted: \(text)")
case .cancelled: print("Cancelled")
case .unhandled: break
}
```

#### Form

```swift
var form = Form(fields: [
    .init(id: "name", label: "Name", validation: [.required, .minLength(2)]),
    .init(id: "email", label: "Email", validation: [.required, .pattern(".*@.*")]),
    .init(id: "age", label: "Age", validation: [.required]),
])
form.render(into: &frame)

form.focusNext()
let isValid = form.validate()
let name = form.value(forField: "name")
```

Validation rules: `.required`, `.minLength(Int)`, `.maxLength(Int)`,
`.pattern(String)`, `.custom(@Sendable (String) -> String?)`.

### Overlay

#### Command Palette

Searchable action palette with fuzzy matching:

```swift
var registry = PaletteRegistry()
registry.register(PaletteAction(id: "save", label: "Save File", keyBinding: "Ctrl-S"))
registry.register(PaletteAction(id: "open", label: "Open File", keyBinding: "Ctrl-O"))
registry.register(PaletteAction(id: "quit", label: "Quit", category: "App"))

var palette = CommandPalette(registry: registry)
palette.show()
palette.updateQuery("file")  // fuzzy-matches "Save File" and "Open File"
palette.selectNext()

if let action = palette.selectedAction {
    print("Selected: \(action.label)")
}

palette.render(into: &frame)
```

#### Toast and NotificationManager

```swift
var notifications = NotificationManager(maxVisible: 3, position: .bottomRight)

notifications.push(Toast(message: "File saved", severity: .success))
notifications.push(Toast(message: "Connection lost", severity: .error, duration: .seconds(5)))

notifications.expireOld(now: .now)
notifications.render(into: &frame, screenWidth: 80, screenHeight: 24)
```

### Layout Widgets

#### Block

Bordered container that returns an inner frame for nested rendering:

```swift
let block = Block(title: "Panel", borders: .all, boxDrawing: .unicode)
var inner = block.render(into: &frame)
// Render content inside the bordered area
myWidget.render(into: &inner)
```

#### Paragraph

```swift
let para = Paragraph(text: "Hello, world!", alignment: .center, wrap: true)
para.render(into: &frame)
```

#### CalendarView

```swift
var cal = CalendarView(
    year: 2026, month: 5,
    selectedDay: 13,
    highlightedDays: [1, 15, 30],
    showWeekNumbers: true
)
cal.render(into: &frame)
```

---

## Animation

### Animation

Duration-based animation tracker with easing:

```swift
var anim = Animation(duration: .milliseconds(300), easing: .easeInOut)
anim.start(at: .now)

// On each frame:
let progress = anim.progress(at: .now)  // 0.0...1.0, eased
let done = anim.isComplete
```

### Easing

Built-in curves: `.linear`, `.easeIn`, `.easeOut`, `.easeInOut`, `.bounce`.

Custom curves:
```swift
let custom = Easing.cubicBezier(x1: 0.68, y1: -0.55, x2: 0.265, y2: 1.55)
let springy = Easing.spring(mass: 1.0, stiffness: 100.0, damping: 10.0)

let value = custom.apply(0.5)  // eased output for linear input 0.5
```

### Transition

Enter/exit transitions with visual effects:

```swift
var transition = Transition(kind: .fade, duration: .milliseconds(300))
transition.enter(at: .now)

let opacity = transition.opacity(at: .now)  // 0.0...1.0
let offset = transition.offset(at: .now, dimension: 80)  // for slide effects

transition.exit(at: .now)  // reverse
```

Transition kinds: `.fade`, `.slideLeft`, `.slideRight`, `.slideUp`, `.slideDown`,
`.expand`, `.collapse`.

All animation types accept a `reduceMotion: Bool` parameter that replaces the
animation with zero-duration for motion-sensitive users.

### AnimatedValue

Interpolates between values over time:

```swift
var animated = AnimatedValue(
    from: 0.0, to: 100.0,
    animation: Animation(duration: .seconds(1), easing: .easeOut)
)
animated.start(at: .now)
let current = animated.value(at: .now)  // Double between 0 and 100
```

Works with any `BinaryFloatingPoint` or `Int`.

---

## Theming and Syntax Highlighting

### Theme

Named collection of semantic colors:

```swift
let theme = Theme.dark  // built-in dark theme
let style = theme.style(fg: \.primary, bg: \.surface, attributes: [.bold])

// Custom theme from JSON
let custom = try ThemeLoader.load(path: "mytheme.json")
```

Built-in themes: `.dark`, `.light`.

### Syntax Highlighting

```swift
let highlighter = SyntaxHighlighter(language: .swift, theme: .default)
let spans = highlighter.highlight("let x = 42")
// [StyledSpan(text: "let", tokenType: .keyword, fg: ...), ...]

// Auto-detect language
let lang = SyntaxLanguage.detect(filename: "main.py")  // .python
```

Supported languages: Swift, Python, JSON, Markdown, JavaScript, TypeScript, Go,
Rust, Ruby, Shell, YAML, TOML, SQL, HTML, CSS, and a generic fallback.

Token types: `.keyword`, `.type`, `.string`, `.number`, `.comment`,
`.decorator`, `.operator`, `.function`, `.variable`, `.plain`.

---

## Image Support

SwiftCLIKit auto-detects the best available image protocol and provides
encoders for each.

```swift
let capability = ImageCapabilityDetector.detect()  // .kitty, .sixel, .iterm2, .none

// Inline image with auto-detection
var image = InlineImage(fileData: pngBytes, width: 40, height: 20)
if let escape = image.escapeSequence() {
    print(escape, terminator: "")
}

// ASCII fallback for terminals without image support
let pixels = PixelData(bytes: rgbaBytes, width: 100, height: 50)!
let cells = ASCIIArt.render(pixels: pixels, width: 40, height: 20)

// Direct encoder access
let kitty = KittyEncoder.encode(data: pngBytes, width: 40)
let sixel = SixelEncoder.encode(pixels: pixels, maxColors: 256)
let iterm = ITermEncoder.encode(data: pngBytes, width: 40, preserveAspectRatio: true)
```

---

## Accessibility

### Settings and Roles

```swift
var settings = AccessibilitySettings(isEnabled: true, verbosity: .verbose)
// Verbosity levels: .minimal (role + label), .standard (+ value), .verbose (+ hint, children)
```

### AccessibleWidget Protocol

Widgets that conform to `AccessibleWidget` expose structured labels:

```swift
let label = AccessibilityLabel(
    role: .table,
    label: "User list",
    value: "3 items",
    hint: "Use arrow keys to navigate",
    childCount: 3
)

label.formatted(verbosity: .standard)  // "table, User list, 3 items"
```

### Announcer

Emits accessibility announcements to stderr or a custom handler:

```swift
let announcer = AccessibilityAnnouncer(
    channel: .stderr,
    settings: AccessibilitySettings(isEnabled: true)
)

announcer.announce("File saved successfully")
announcer.focusChanged(from: "name", to: "email", label: emailLabel)
announcer.valueChanged(widgetID: "progress", label: progressLabel)
```

---

## Formatting Utilities

Human-readable formatting for common data types:

```swift
Formatting.elapsed(3661)           // "1h 1m 1s"
Formatting.duration(0.5)           // "500ms"
Formatting.bytes(1_073_741_824)    // "1.00 GB"
Formatting.time(Date())            // "14:30:45"
Formatting.timeShort(Date())       // "2:30 PM"
Formatting.rate(1500.0, unit: "req/s")  // "1.50K req/s"
```

---

## Debug and Testing

### PerfTracker

Collects per-frame timing data for performance monitoring:

```swift
var perf = PerfTracker()

// In your render loop:
perf.beginFrame()
// ... update ...
perf.recordUpdateDuration(updateTime)
// ... render ...
perf.recordViewDuration(renderTime)
perf.endFrame()

print("FPS: \(perf.currentFPS)")
print("Avg frame: \(perf.averageFrameTime)")
print("Total frames: \(perf.totalFrameCount)")
```

### Session Recording and Playback

Record a session for replay and debugging:

```swift
let recorder = SessionRecorder<MyMessage>(outputPath: "session.jsonl")
recorder.record(key: "a", timestamp: 0.0)
recorder.record(resize: 120, height: 40, timestamp: 0.5)
recorder.record(message: MyMessage.save, timestamp: 1.0)
try recorder.close()

// Replay
let player = SessionPlayer(
    inputPath: "session.jsonl",
    initialModel: MyModel(),
    update: myUpdate
)
let snapshots = try player.play()  // [Model] at each step
```

### Snapshot Testing

Compare `CellBuffer` output against golden files:

```swift
let buffer = CellBuffer(width: 40, height: 10)
// ... render into buffer ...

SnapshotTesting.assertSnapshot(buffer, name: "my_widget")
// First run: records snapshot. Subsequent runs: compares against it.

// Manual comparison
let rendered = SnapshotTesting.renderPlainText(buffer)
if let diff = SnapshotTesting.compare(buffer, goldenFile: "expected.txt") {
    print("Mismatch: \(diff)")
}
```

### TestBackend

In-memory terminal backend for headless testing:

```swift
let backend = TestBackend(width: 80, height: 24)

// Inject events
await backend.inject(.key(.character("a")))
await backend.injectSequence([.key(.arrowUp), .key(.enter)])

// Inspect state
let buffer = backend.currentBuffer
let history = backend.renderHistory
let output = backend.allWrittenOutput
let isRaw = backend.isRawMode
```

---

## SSH Module

`SwiftCLIKitSSH` lets you serve your terminal application over SSH. Each
connection gets its own `SSHBackend` that conforms to `TerminalBackend`.

```swift
import SwiftCLIKitSSH

let server = SSHServer(
    host: "0.0.0.0",
    port: 2222,
    hostKeySource: .generateEphemeral,
    configuration: SSHConfiguration(
        maxConnections: 10,
        idleTimeout: .seconds(300),
        authMode: .password { user, pass in user == "admin" && pass == "secret" }
    )
)

try await server.start { backend, session in
    print("Connection from \(session.remoteAddress)")
    // `backend` conforms to TerminalBackend — use it with App, widgets, etc.
    let app = App(/* ... use backend ... */)
    try await app.run()
}
```

Auth modes: `.none`, `.password((String, String) -> Bool)`, `.publicKey`.

Host key sources: `.generateEphemeral`, `.filePath(String)`.

---

## Platform Support

| Platform | Raw mode | Key reading | ioctl size | SIGWINCH | Mouse | SSH |
|----------|----------|-------------|------------|----------|-------|-----|
| macOS    | Yes      | Yes         | Yes        | Yes      | Yes   | Yes |
| Linux    | Yes      | Yes         | Yes        | Yes      | Yes   | Yes |
| Other    | No-op    | Pipe only   | Fallback   | No-op    | No    | No  |

On unsupported platforms, `RawTerminal` skips raw mode but `readByte()` still
works on pipe input. `TerminalSize.current()` returns an 80x24 fallback.

---

## Integration

Add SwiftCLIKit to your `Package.swift`:

```swift
let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/jpurnell/SwiftCLIKit.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: ["SwiftCLIKit"]
        ),
    ]
)
```

For SSH support, add the SSH module dependency:

```swift
.executableTarget(
    name: "MySSHApp",
    dependencies: ["SwiftCLIKit", "SwiftCLIKitSSH"]
)
```

Then `import SwiftCLIKit` (and `import SwiftCLIKitSSH` if needed) in any source
file. See the `swiftclikit-examples` target for complete working programs
including a hello-world terminal app, progress spinner demo, system monitor
dashboard, and live training dashboard.
