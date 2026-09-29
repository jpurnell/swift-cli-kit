//
//  Frame.swift
//  SwiftCLIKit
//
//  Created by Justin Purnell on 2026-04-10.
//

import Foundation

/// A rendering surface backed by a shared ``BufferRef`` and scoped to a ``Rect``.
///
/// Multiple frames can share the same underlying buffer — writes from any
/// frame (including sub-frames) are visible to all others. This enables
/// widget composition: a parent frame creates sub-frames for child widgets,
/// and all writes land in the same buffer.
///
/// ```swift
/// // `Frame(bufferRef:)` is internal; a caller builds one from a buffer.
/// var frame = Frame(
///     buffer: CellBuffer(width: 80, height: 24),
///     rect: Rect(x: 0, y: 0, width: 80, height: 24)
/// )
/// var sub = frame.subFrame(Rect(x: 5, y: 5, width: 10, height: 5))
/// sub.writeText("Hello", x: 0, y: 0)
/// // "Hello" is visible in frame.cellBuffer at (5, 5)
/// ```
public struct Frame: Sendable {
    /// The rectangular region this frame covers.
    public let rect: Rect

    /// Shared reference to the underlying cell buffer.
    private let bufferRef: BufferRef

    /// Creates a frame backed by the given buffer and scoped to the given rect.
    public init(buffer: CellBuffer, rect: Rect) {
        self.bufferRef = BufferRef(buffer)
        self.rect = rect
    }

    /// Creates a frame sharing an existing buffer reference.
    internal init(bufferRef: BufferRef, rect: Rect) {
        self.bufferRef = bufferRef
        self.rect = rect
    }

    /// Sets a single cell at the given position (relative to the frame's rect).
    ///
    /// Coordinates are translated to absolute buffer positions. Writes outside
    /// the frame's rect are silently ignored.
    public mutating func setCell(x: Int, y: Int, cell: Cell) {
        let absX = rect.x + x
        let absY = rect.y + y
        guard rect.contains(x: absX, y: absY) else { return }
        bufferRef.buffer[absX, absY] = cell
    }

    /// Writes text horizontally starting at the given position (relative to the frame's rect).
    ///
    /// Characters that fall outside the frame's rect are skipped. Wide characters
    /// (CJK, emoji) consume two columns.
    public mutating func writeText(
        _ text: String,
        x: Int,
        y: Int,
        fg: Color = .default,
        bg: Color = .default,
        attributes: CellAttributes = []
    ) {
        var col = x
        for ch in text {
            let absX = rect.x + col
            let absY = rect.y + y
            guard rect.contains(x: absX, y: absY) else {
                let charWidth = UnicodeWidth.width(of: ch)
                col += max(charWidth, 1)
                continue
            }
            let charWidth = UnicodeWidth.width(of: ch)
            bufferRef.buffer[absX, absY] = Cell(character: ch, fg: fg, bg: bg, attributes: attributes)
            if charWidth == 2 {
                let nextX = absX + 1
                if rect.contains(x: nextX, y: absY) {
                    bufferRef.buffer[nextX, absY] = Cell(character: " ", fg: fg, bg: bg, attributes: attributes)
                }
                col += 2
            } else {
                col += max(charWidth, 1)
            }
        }
    }

    /// Returns a sub-frame clipped to the intersection of this frame's rect and the given rect.
    ///
    /// The sub-frame shares the same underlying buffer — writes into the sub-frame
    /// are visible in the parent frame and vice versa.
    public func subFrame(_ subRect: Rect) -> Frame {
        guard let clipped = rect.intersection(subRect) else {
            return Frame(bufferRef: bufferRef, rect: Rect(x: 0, y: 0, width: 0, height: 0))
        }
        return Frame(bufferRef: bufferRef, rect: clipped)
    }

    /// The underlying buffer after rendering.
    ///
    /// Since all frames sharing the same ``BufferRef`` see the same data,
    /// extracting the buffer from any frame returns the complete result.
    public var cellBuffer: CellBuffer { bufferRef.buffer }
}
