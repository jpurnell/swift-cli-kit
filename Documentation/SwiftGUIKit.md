# SwiftGUIKit

**One scene, many surfaces** — describe a UI once as a semantic scene graph and
render it to a terminal *and* to native SwiftUI, with Apple's HIG as the baseline.

SwiftGUIKit extends [SwiftCLIKit](../README.md) from a terminal toolkit into a
cross-surface UI kit.

---

## The idea

You build a value — a `Node` — that describes *what* a UI is (a gauge, a table, a
bordered block of fields) in terms of **design tokens**, never literal colors,
characters, or pixel sizes. A *renderer* then interprets that value for a
specific surface:

| Renderer | Product | Draws to |
|----------|---------|----------|
| `CellRenderer` | `SwiftGUIKit` | a terminal `Frame` (via SwiftCLIKit) |
| `SwiftUIRenderer` | `SwiftGUIKitSwiftUI` | native SwiftUI views |

Because the scene graph is a pure `Equatable`, `Sendable` value, one description
drives every surface. Adding a *surface* is cheap — you write one renderer. That
is the library's thesis: the expression-problem trade is made deliberately in
favor of cheap surfaces over cheap widgets.

---

## Quick start

```swift
import SwiftGUIKit

// 1. Describe the UI once, in tokens.
let scene: Node = .vstack([
    Paragraph(text: "Build health").node(color: .accent),
    Gauge(ratio: 0.82, label: "82%").node(),
    Block(title: "Checks").node(child: .vstack([
        Checkbox(label: "safety",    isChecked: true).node(id: "safety"),
        Checkbox(label: "recursion", isChecked: true).node(id: "recursion"),
    ])),
])
```

Render it to a terminal frame:

```swift
import SwiftCLIKit

var frame = Frame(buffer: CellBuffer(width: 40, height: 12),
                  rect: Rect(x: 0, y: 0, width: 40, height: 12))
let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark),
                            context: .terminalTruecolor)
renderer.render(scene, into: &frame)
```

…or render the **same** scene to native SwiftUI, handling interaction:

```swift
import SwiftGUIKitSwiftUI   // #if canImport(SwiftUI)

let view = SwiftUIRenderer().view(for: scene) { action in
    switch action {
    case let .toggled(id, on):      model.setCheck(id, on)
    case let .selected(id, index):  model.select(id, index)
    default:                        break
    }
}
```

---

## The token system — HIG by deference

A `TokenResolver` maps semantic roles (`ColorRole.accent`, `TypeRole.heading`,
`SpaceToken.m`) to concrete values for a surface, reading a `DesignContext`
(appearance, density, glyph capability, color depth, surface kind).

The Apple resolver resolves *by deference*:

| Role | Resolves to |
|------|-------------|
| `ColorRole.accent` | `.accentColor` |
| `ColorRole.destructive` / `.success` / `.warning` | `.red` / `.green` / `.yellow` |
| `TypeRole.body` / `.heading` / `.title` | `.body` / `.headline` / `.largeTitle` (Dynamic Type) |
| symbols | SF Symbols |
| spacing | the system metrics |

Because it returns the system's *own* semantic values, native output **cannot
drift below the HIG** — the baseline is inherited, not reimplemented. The terminal
resolver (`TerminalTokenResolver`) maps the same roles to ANSI styles and box
characters, with an ASCII "mono floor" for the poorest terminals.

---

## Interaction — TEA, not closures

Interactive nodes carry a stable `id`. A renderer wires its controls to emit a
`NodeAction` — a *value*, not a closure baked into the tree:

| Action | Emitted by |
|--------|-----------|
| `.toggled(id:_:)` | checkbox |
| `.selected(id:_:)` | radio group, tabs, dropdown, menu, list, table |
| `.nodeSelected(id:_:)` | tree (selection is by node identity, not row index) |
| `.textChanged(id:_:)` | text field, text area, form field |
| `.submitted(id:)` | text field / form field on Enter |

Your app handles the action to update its model and re-derive the scene —
Model → View → Action, Elm-style. Because actions are values, `Node` stays a plain
`Equatable` tree with no per-app `Message` generic.

---

## Building a scene

Every SwiftCLIKit widget projects into a `Node` via a `.node()` method
(`Gauge(…).node()`, `Table(…).node()`, `Tree(…).node(id:)`), resolving away
generics and render closures at the **projection boundary** so the scene graph
stays monomorphic and `Equatable`.

Containers compose them:

- `Node.vstack(_:)` / `Node.hstack(_:)` — axis stacks
- `Node.padding(_:child:)` — inset by a spacing token
- `Block(…).node(child:)` — a bordered, titled container
- `Node.stack(axis:spacing:children:)` — the general form, with per-child
  `SizeConstraint`: `.fixed(n)`, `.flex(weight)`, or `.fit` (size to measured
  intrinsic content)

### The node catalog

**Indicators** gauge · progressBar · sparkline · barChart ·
**Collections** list · table · tree · menu ·
**Selection** radioGroup · tabs · dropdown · checkbox ·
**Text** paragraph · textField · textArea ·
**Composite** form · calendar ·
**Containers** stack · spacer · padding · block

Every node renders on both surfaces; every interactive node dispatches a
`NodeAction`.

---

## Requirements

- Swift 6.0+
- Terminal surface: macOS 15+ or Linux
- SwiftUI surface (`SwiftGUIKitSwiftUI`): any Apple platform with SwiftUI

## Installation

```swift
dependencies: [
    .package(path: "../SwiftCLIKit"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SwiftGUIKit", package: "SwiftCLIKit"),
        // Apple platforms only:
        .product(name: "SwiftGUIKitSwiftUI", package: "SwiftCLIKit"),
    ]),
]
```
