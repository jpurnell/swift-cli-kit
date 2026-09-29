// Shadow.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// A simulated drop-shadow rendered as offset darker cells behind a window.
///
/// Shadows are purely visual -- they render darker cells at an offset from
/// the window rectangle, giving the appearance of depth.
///
/// ```swift
/// let shadow = Shadow.default  // offset (1,1), dark gray background
/// let custom = Shadow(offsetX: 2, offsetY: 1, bg: .ansi8(.black))
/// ```
public struct Shadow: Sendable, Equatable {
    /// Horizontal offset in columns (positive = right).
    public var offsetX: Int
    /// Vertical offset in rows (positive = down).
    public var offsetY: Int
    /// The background color for shadow cells.
    public var bg: Color

    /// The default shadow: 1 cell right, 1 cell down, dark gray background.
    public static let `default` = Shadow(offsetX: 1, offsetY: 1, bg: .ansi8(.black))

    /// Creates a shadow with the given offset and background color.
    /// - Parameters:
    ///   - offsetX: Horizontal offset in columns (default: 1).
    ///   - offsetY: Vertical offset in rows (default: 1).
    ///   - bg: Background color for shadow cells (default: black).
    public init(offsetX: Int = 1, offsetY: Int = 1, bg: Color = .ansi8(.black)) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.bg = bg
    }

    /// Returns the shadow rectangle for a given window rectangle.
    /// - Parameter windowRect: The window's bounding rectangle.
    /// - Returns: The shadow's bounding rectangle, offset from the window.
    public func shadowRect(for windowRect: Rect) -> Rect {
        Rect(
            x: windowRect.x + offsetX,
            y: windowRect.y + offsetY,
            width: windowRect.width,
            height: windowRect.height
        )
    }
}
