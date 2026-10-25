// Event.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A terminal event from the event stream.
///
/// Events are produced by ``EventStream`` and consumed by the ``App`` runtime.
/// They represent user input (keys, mouse), terminal state changes (resize),
/// or application-defined payloads (custom).
///
/// ```swift
/// let event: Event = .key(.arrowUp)
/// switch event {
/// case .key(let key): print("Key: \(key)")
/// case .mouse(let m): print("Mouse at \(m.column),\(m.row)")
/// case .resize(let w, let h): print("Resized to \(w)x\(h)")
/// case .custom(let v): print("Custom: \(v)")
/// }
/// ```
public enum Event: Sendable {
    /// A keyboard event.
    case key(Key)
    /// A mouse button or scroll event.
    case mouse(MouseEvent)
    /// The terminal was resized to the given width and height.
    case resize(width: Int, height: Int)
    /// An application-defined event payload.
    case custom(any Sendable)
}
