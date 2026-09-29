# Cell Rendering Guide

SwiftCLIKit provides a cell-based terminal rendering pipeline inspired by
[ratatui](https://ratatui.rs). This guide covers every layer from raw cells to
finished widgets.

---

## 1. The Render Cycle

Each frame of terminal output follows the same sequence:

1. **Create a `CellBuffer`** sized to the terminal.
2. **Define the root `Rect`** covering the full buffer.
3. **Split the rect** into sub-regions with `Layout.split`.
4. **Wrap each region in a `Frame`** (or derive sub-frames).
5. **Render widgets** (`Block`, `Paragraph`, ...) into the frames.
6. **Diff the buffer** against the previous frame with `DiffRenderer`.
7. **Write the ANSI output** to stdout.

```swift
// Pseudocode for one frame
var buffer = CellBuffer(width: cols, height: rows)
let root = Rect(x: 0, y: 0, width: cols, height: rows)
var frame = Frame(buffer: buffer, rect: root)

// ... layout and render ...

let ansi = renderer.render(current: frame.cellBuffer, previous: prev)
print(ansi, terminator: "")
prev = frame.cellBuffer
```

---

## 2. Immediate-Mode Rendering

SwiftCLIKit uses an immediate-mode model:

- **Widgets are pure functions.** They accept a `Frame`, write cells, and
  return. They hold no persistent state of their own.
- **The caller owns all state.** Your application decides what to draw on each
  frame, builds the widgets, and renders them. There is no retained widget tree.
- **Every frame is drawn from scratch** into a fresh `CellBuffer`. The
  `DiffRenderer` handles the optimization of only sending changes to the
  terminal.

This keeps the rendering layer simple and predictable. If your data changes,
re-render. If nothing changes, the diff produces an empty string.

---

## 3. CellBuffer Basics

A `CellBuffer` is a flat 2D grid of `Cell` values.

### Creation

```swift
var buffer = CellBuffer(width: 80, height: 24)
```

All cells start as `Cell.empty` (a space with default colors and no
attributes).

### Reading and writing cells

Use the subscript with `(x, y)` coordinates:

```swift
let cell = buffer[5, 3]            // read
buffer[5, 3] = Cell(character: "X", fg: .ansi8(.red))  // write
```

Out-of-bounds reads return `Cell.empty`; out-of-bounds writes are silently
ignored.

### Writing text

```swift
buffer.writeText("Hello", at: (x: 10, y: 0), fg: .ansi8(.green))
```

Wide characters (CJK, emoji) consume two columns; `writeText` writes a
continuation space in the second column automatically.

### Filling a region

```swift
let region = Rect(x: 0, y: 0, width: 80, height: 1)
buffer.fill(region, with: Cell(character: "-"))
```

### Clearing

```swift
buffer.clear()  // resets every cell to Cell.empty
```

---

## 4. Layout Engine

### Rect

`Rect` is an axis-aligned rectangle in zero-based terminal coordinates:

```swift
let area = Rect(x: 0, y: 0, width: 100, height: 24)
```

Useful properties and methods:

| Member          | Description                              |
|-----------------|------------------------------------------|
| `area`          | Total cell count (`width * height`).     |
| `isEmpty`       | True when area is zero or negative.      |
| `intersection`  | Overlap with another rect, or `nil`.     |
| `contains(x:y:)`| Hit-tests a point.                      |
| `split`         | Subdivides via `Layout.Constraint`.      |

### Constraints

`Layout.Constraint` controls how space is distributed in a split:

| Constraint          | Meaning                                   |
|---------------------|-------------------------------------------|
| `.fixed(n)`         | Exactly `n` columns or rows.              |
| `.percentage(p)`    | `p`% of available space (0--100).         |
| `.ratio(n, d)`      | Proportional share `n/d` of total space.  |
| `.min(n)`           | Flexible, but at least `n`.              |
| `.max(n)`           | Flexible, but at most `n`.               |

### Horizontal and vertical splits

```swift
let chunks = Layout.split(
    area: Rect(x: 0, y: 0, width: 100, height: 24),
    direction: .horizontal,
    constraints: [.fixed(20), .min(10), .fixed(30)]
)
// chunks[0]: 20 cols on the left
// chunks[1]: remaining space (at least 10)
// chunks[2]: 30 cols on the right
```

Or use the convenience method on `Rect`:

```swift
let rows = area.split(direction: .vertical, constraints: [.fixed(1), .min(0), .fixed(1)])
```

---

## 5. Frames

A `Frame` binds a `CellBuffer` to a `Rect`, providing a coordinate-translated
rendering surface.

### Coordinate translation

All `Frame` methods take positions relative to the frame's origin. The frame
translates them to absolute buffer coordinates:

```swift
var frame = Frame(buffer: buffer, rect: Rect(x: 10, y: 5, width: 40, height: 10))
frame.setCell(x: 0, y: 0, cell: Cell(character: "*"))
// Writes to buffer[10, 5]
```

### Clipping

Writes outside the frame's rect are silently discarded. This means widgets
never corrupt neighboring regions.

### Sub-frames

`subFrame(_:)` creates a child frame scoped to the intersection of the
parent's rect and the requested rect:

```swift
let inner = frame.subFrame(Rect(x: 12, y: 6, width: 36, height: 8))
```

If the rects do not overlap, the sub-frame has zero area and all writes are
no-ops.

### Extracting the buffer

After rendering, pull the completed buffer out for diffing:

```swift
let finalBuffer = frame.cellBuffer
```

---

## 6. DiffRenderer

`DiffRenderer` compares the current `CellBuffer` against a previous one and
emits only the ANSI escape sequences needed to update changed cells.

### Why it is fast

- Unchanged cells are skipped entirely (no cursor movement, no SGR output).
- Adjacent changed cells share a cursor position (no redundant `\e[row;colH`).
- Style changes (SGR) are emitted only when the foreground, background, or
  attributes differ from the last written cell.

### Full vs. differential

Pass `previous: nil` for a full redraw (still skips `Cell.empty` cells).
Pass the previous buffer for a differential update.

```swift
var renderer = DiffRenderer()
let full = renderer.render(current: buffer, previous: nil)      // first paint
let diff = renderer.render(current: buffer, previous: oldBuffer) // incremental
```

---

## 7. Widgets

### Paragraph

`Paragraph` renders text into a frame with word wrapping and alignment.

```swift
let para = Paragraph(text: "Long text that wraps at the frame edge.", alignment: .left, wrap: true)
para.render(into: &frame, fg: .ansi8(.cyan))
```

Alignment options: `.left`, `.center`, `.right`.

When `wrap` is `false`, text is truncated to a single line.

### Block

`Block` draws a border around a frame region and returns an inner `Frame` for
child content.

```swift
let block = Block(title: "Info", borders: .all, boxDrawing: .unicode)
var innerFrame = block.render(into: &frame)
// Render children into innerFrame
```

`BorderSet` controls which sides are drawn (`.top`, `.bottom`, `.left`,
`.right`, `.all`, `.none`). Two box-drawing presets are provided:
`.unicode` (light box-drawing characters) and `.ascii` (`+`, `-`, `|`).

Titles are rendered inline in the top border and automatically truncated if
they exceed the available width.

---

## 8. Worked Example

The following builds a two-panel layout with bordered content and paragraphs.
It is a complete, runnable function (assuming SwiftCLIKit is imported).

```swift
import SwiftCLIKit

func renderDashboard(cols: Int, rows: Int, previous: CellBuffer?) -> (String, CellBuffer) {
    // 1. Create the buffer and root frame.
    let buffer = CellBuffer(width: cols, height: rows)
    let root = Rect(x: 0, y: 0, width: cols, height: rows)
    var frame = Frame(buffer: buffer, rect: root)

    // 2. Split the root into a header row and a body.
    let verticalChunks = Layout.split(
        area: root,
        direction: .vertical,
        constraints: [.fixed(3), .min(0)]
    )
    let headerRect = verticalChunks[0]
    let bodyRect = verticalChunks[1]

    // 3. Render a bordered header with a centered title.
    var headerFrame = frame.subFrame(headerRect)
    let headerBlock = Block(title: "Dashboard", borders: .all, titleAlignment: .center)
    var headerInner = headerBlock.render(into: &headerFrame)
    let titlePara = Paragraph(text: "SwiftCLIKit v0.3.0", alignment: .center)
    titlePara.render(into: &headerInner, fg: .ansi8(.cyan))

    // 4. Split the body into two side-by-side panels.
    let horizontalChunks = Layout.split(
        area: bodyRect,
        direction: .horizontal,
        constraints: [.percentage(50), .percentage(50)]
    )

    // 5. Left panel: bordered block with a paragraph.
    var leftFrame = frame.subFrame(horizontalChunks[0])
    let leftBlock = Block(title: "Status", borders: .all)
    var leftInner = leftBlock.render(into: &leftFrame)
    let statusText = Paragraph(
        text: "All systems operational. No alerts.",
        alignment: .left,
        wrap: true
    )
    statusText.render(into: &leftInner, fg: .ansi8(.green))

    // 6. Right panel: bordered block with right-aligned text.
    var rightFrame = frame.subFrame(horizontalChunks[1])
    let rightBlock = Block(title: "Log", borders: .all)
    var rightInner = rightBlock.render(into: &rightFrame)
    let logText = Paragraph(
        text: "10:04 Connected. 10:05 Heartbeat OK. 10:06 Sync complete.",
        alignment: .right,
        wrap: true
    )
    logText.render(into: &rightInner)

    // 7. Diff and return.
    var renderer = DiffRenderer()
    let current = frame.cellBuffer
    let ansi = renderer.render(current: current, previous: previous)
    return (ansi, current)
}

// Usage:
// let (output, buffer) = renderDashboard(cols: 80, rows: 24, previous: nil)
// print(output, terminator: "")
```

This produces a terminal layout like:

```
+---------------------Dashboard----------------------+
|            SwiftCLIKit v0.3.0                      |
+------------------------+---------------------------+
| Status                 | Log                       |
| All systems            |   10:04 Connected. 10:05  |
| operational. No        |   Heartbeat OK. 10:06     |
| alerts.                |           Sync complete.  |
|                        |                           |
+------------------------+---------------------------+
```

The next frame, pass the returned `buffer` as `previous` and only changed
cells will be redrawn.
