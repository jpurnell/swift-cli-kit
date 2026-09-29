# SwiftCLIKit

Pure Swift terminal abstraction library -- raw mode, input parsing, line editing, and rendering primitives with zero C dependencies.

> **SwiftGUIKit** — the cross-surface UI kit built on SwiftCLIKit: describe a UI
> once as a semantic scene graph and render it to a terminal *and* native SwiftUI,
> with Apple's HIG as the baseline. See **[Documentation/SwiftGUIKit.md](Documentation/SwiftGUIKit.md)**.

## Requirements

- **Swift 6.2+** — the manifest is `swift-tools-version: 6.2`; earlier toolchains cannot parse it
- macOS 15+ or Linux

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/swift-cli-kit.git", from: "1.4.1"),
]
```

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

## Documentation

- [SwiftCLIKitGuide.md](SwiftCLIKitGuide.md) — the terminal toolkit.
- [Documentation/SwiftGUIKit.md](Documentation/SwiftGUIKit.md) — the cross-surface UI kit (terminal + SwiftUI).

## License

MIT
