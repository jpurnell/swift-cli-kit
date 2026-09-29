// Scrollbar.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A scrollbar widget that indicates the current scroll position within overflowing content.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let scrollbar = Scrollbar(
///     orientation: .vertical,
///     contentLength: 100,
///     viewportSize: 20,
///     offset: 25
/// )
/// scrollbar.render(into: &frame)
/// ```
public struct Scrollbar: Sendable {
    /// The orientation of a scrollbar.
    public enum Orientation: Sendable, Equatable {
        /// A vertical scrollbar.
        case vertical
        /// A horizontal scrollbar.
        case horizontal
    }

    /// The scrollbar orientation.
    public var orientation: Orientation
    /// The total content length in the scroll direction.
    public var contentLength: Int
    /// The viewport size in the scroll direction.
    public var viewportSize: Int
    /// The current scroll offset.
    public var offset: Int
    /// The style for the track (background).
    public var trackStyle: CellStyle
    /// The style for the thumb (indicator).
    public var thumbStyle: CellStyle

    /// Creates a scrollbar widget.
    /// - Parameters:
    ///   - orientation: Vertical or horizontal (default: vertical).
    ///   - contentLength: The total content length.
    ///   - viewportSize: The viewport size.
    ///   - offset: The current scroll offset (default: 0).
    ///   - trackStyle: Style for the track (default: default style).
    ///   - thumbStyle: Style for the thumb (default: default style).
    public init(
        orientation: Orientation = .vertical,
        contentLength: Int,
        viewportSize: Int,
        offset: Int = 0,
        trackStyle: CellStyle = CellStyle(),
        thumbStyle: CellStyle = CellStyle()
    ) {
        self.orientation = orientation
        self.contentLength = contentLength
        self.viewportSize = viewportSize
        self.offset = offset
        self.trackStyle = trackStyle
        self.thumbStyle = thumbStyle
    }

    /// Renders this scrollbar into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        let trackLength: Int
        switch orientation {
        case .vertical:
            trackLength = frame.rect.height
        case .horizontal:
            trackLength = frame.rect.width
        }

        guard trackLength > 0 else { return }

        let trackChar: Character = "░"
        let thumbChar: Character = "█"

        // When content fits viewport, fill entire track with thumb
        guard contentLength > viewportSize else {
            for i in 0..<trackLength {
                switch orientation {
                case .vertical:
                    frame.setCell(x: 0, y: i, cell: Cell(
                        character: thumbChar,
                        fg: thumbStyle.fg, bg: thumbStyle.bg, attributes: thumbStyle.attributes
                    ))
                case .horizontal:
                    frame.setCell(x: i, y: 0, cell: Cell(
                        character: thumbChar,
                        fg: thumbStyle.fg, bg: thumbStyle.bg, attributes: thumbStyle.attributes
                    ))
                }
            }
            return
        }

        let thumbSize = max(1, trackLength * viewportSize / contentLength)
        let scrollRange = max(1, contentLength - viewportSize)
        let thumbOffset = (offset * (trackLength - thumbSize)) / scrollRange

        for i in 0..<trackLength {
            let isThumb = i >= thumbOffset && i < thumbOffset + thumbSize
            let ch = isThumb ? thumbChar : trackChar
            let style = isThumb ? thumbStyle : trackStyle

            switch orientation {
            case .vertical:
                frame.setCell(x: 0, y: i, cell: Cell(
                    character: ch,
                    fg: style.fg, bg: style.bg, attributes: style.attributes
                ))
            case .horizontal:
                frame.setCell(x: i, y: 0, cell: Cell(
                    character: ch,
                    fg: style.fg, bg: style.bg, attributes: style.attributes
                ))
            }
        }
    }
}
