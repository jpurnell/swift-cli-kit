// WindowManager.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Manages a stack of floating windows with Z-order rendering.
///
/// `WindowManager` is a value type that maintains an ordered collection of
/// ``Window`` values. It renders windows in Z-order onto a ``CellBuffer``,
/// with optional modal dimming and shadow effects.
///
/// ```swift
/// var buffer = CellBuffer(width: 80, height: 24)
/// var wm = WindowManager()
/// wm.push(Window(id: "dialog", rect: Rect(x: 5, y: 3, width: 30, height: 10),
///                render: { frame in frame.writeText("Hello", x: 1, y: 1) }))
/// wm.render(into: &buffer, baseView: { frame in
///     frame.writeText("Base content", x: 0, y: 0)
/// })
/// ```
public struct WindowManager: Sendable {
    /// The managed windows (not necessarily sorted by Z).
    public private(set) var windows: [Window]

    /// Creates a window manager with the given initial windows.
    /// - Parameter windows: Initial window collection (default: empty).
    public init(windows: [Window] = []) {
        self.windows = windows
    }

    /// Adds a window to the manager.
    /// - Parameter window: The window to add.
    public mutating func push(_ window: Window) {
        windows.append(window)
    }

    /// Removes the window with the given ID, if present.
    /// - Parameter id: The ID of the window to remove.
    public mutating func remove(id: String) {
        windows.removeAll { $0.id == id }
    }

    /// Brings the window with the given ID to the front by assigning it
    /// the highest Z-index plus one.
    /// - Parameter id: The ID of the window to bring forward.
    public mutating func bringToFront(id: String) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let maxZ = windows.map(\.zIndex).max() ?? 0
        windows[index].zIndex = maxZ + 1
    }

    /// Sends the window with the given ID to the back by assigning it
    /// the lowest Z-index minus one.
    /// - Parameter id: The ID of the window to send back.
    public mutating func sendToBack(id: String) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let minZ = windows.map(\.zIndex).min() ?? 0
        windows[index].zIndex = minZ - 1
    }

    /// The topmost modal window, if any.
    public var topModal: Window? {
        sortedByZ.last(where: { $0.isModal })
    }

    /// All windows sorted by Z-index (lowest first).
    public var sortedByZ: [Window] {
        windows.sorted { $0.zIndex < $1.zIndex }
    }

    /// Renders all windows in Z-order onto the given buffer.
    ///
    /// The rendering pipeline:
    /// 1. Render the base view into the full buffer.
    /// 2. If a modal window exists, dim all cells in the buffer.
    /// 3. For each window in Z-order, render shadow (if any), then window content.
    ///
    /// - Parameters:
    ///   - buffer: The cell buffer to render into.
    ///   - baseView: Closure that renders the base application view.
    public func render(
        into buffer: inout CellBuffer,
        baseView: (inout Frame) -> Void
    ) {
        let fullRect = Rect(x: 0, y: 0, width: buffer.width, height: buffer.height)

        // 1. Render base view
        var baseFrame = Frame(buffer: buffer, rect: fullRect)
        baseView(&baseFrame)
        buffer = baseFrame.cellBuffer

        let sorted = sortedByZ
        let hasModal = sorted.contains { $0.isModal }

        // 2. Dim background if any modal window exists
        if hasModal {
            dimBuffer(&buffer, area: fullRect)
        }

        // 3. Render each window in Z-order
        for window in sorted {
            // Render shadow first (below the window)
            if let shadow = window.shadow {
                let shadowRect = shadow.shadowRect(for: window.rect)
                renderShadow(into: &buffer, shadowRect: shadowRect, windowRect: window.rect, shadow: shadow)
            }

            // Render window content
            var windowFrame = Frame(buffer: buffer, rect: window.rect)
            window.render(&windowFrame)
            buffer = windowFrame.cellBuffer
        }
    }

    // MARK: - Private helpers

    /// Dims all cells in the buffer within the given area by changing their
    /// attributes to dim.
    private func dimBuffer(_ buffer: inout CellBuffer, area: Rect) {
        let minX = max(area.x, 0)
        let minY = max(area.y, 0)
        let maxX = min(area.x + area.width, buffer.width)
        let maxY = min(area.y + area.height, buffer.height)
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX {
                var cell = buffer[x, y]
                cell.attributes = cell.attributes.union(.dim)
                buffer[x, y] = cell
            }
        }
    }

    /// Renders shadow cells at the shadow rect, but only where they do not
    /// overlap with the window rect itself.
    private func renderShadow(
        into buffer: inout CellBuffer,
        shadowRect: Rect,
        windowRect: Rect,
        shadow: Shadow
    ) {
        let minX = max(shadowRect.x, 0)
        let minY = max(shadowRect.y, 0)
        let maxX = min(shadowRect.x + shadowRect.width, buffer.width)
        let maxY = min(shadowRect.y + shadowRect.height, buffer.height)
        guard minX < maxX, minY < maxY else { return }

        for y in minY..<maxY {
            for x in minX..<maxX {
                // Skip cells that fall within the window rect
                guard !windowRect.contains(x: x, y: y) else { continue }
                buffer[x, y] = Cell(character: " ", bg: shadow.bg)
            }
        }
    }
}
