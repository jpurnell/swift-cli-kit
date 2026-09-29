// Block.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A set of border sides to draw on a ``Block``.
///
/// `BorderSet` is an `OptionSet` that selects which sides of a block's border
/// are rendered. Combine cases with array literal syntax:
/// ```swift
/// let sides: BorderSet = [.top, .bottom]
/// ```
public struct BorderSet: OptionSet, Sendable, Equatable {
    /// The raw integer value of the option set.
    public let rawValue: UInt8
    /// Creates a border-set option set from a raw value.
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// The top border.
    public static let top    = BorderSet(rawValue: 1 << 0)
    /// The bottom border.
    public static let bottom = BorderSet(rawValue: 1 << 1)
    /// The left border.
    public static let left   = BorderSet(rawValue: 1 << 2)
    /// The right border.
    public static let right  = BorderSet(rawValue: 1 << 3)
    /// All four borders.
    public static let all: BorderSet = [.top, .bottom, .left, .right]
    /// No borders.
    public static let none   = BorderSet([])
}

/// A bordered container widget that wraps other content.
///
/// `Block` renders a border around a frame region and returns an inner ``Frame``
/// for child widgets to render into.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let block = Block(title: "Status", borders: .all, boxDrawing: .unicode)
/// var innerFrame = block.render(into: &frame)
/// // Render child widgets into innerFrame
/// ```
public struct Block: Sendable {
    /// An optional title rendered in the top border.
    public var title: String?
    /// Which borders to draw.
    public var borders: BorderSet
    /// The box-drawing character set.
    public var boxDrawing: BoxDrawing
    /// Alignment of the title within the top border.
    public var titleAlignment: Paragraph.Alignment

    /// Creates a block widget.
    /// - Parameters:
    ///   - title: Optional title for the top border.
    ///   - borders: Which borders to draw (default: all).
    ///   - boxDrawing: Character set for border rendering (default: unicode).
    ///   - titleAlignment: Title alignment (default: left).
    public init(
        title: String? = nil,
        borders: BorderSet = .all,
        boxDrawing: BoxDrawing = .unicode,
        titleAlignment: Paragraph.Alignment = .left
    ) {
        self.title = title
        self.borders = borders
        self.boxDrawing = boxDrawing
        self.titleAlignment = titleAlignment
    }

    /// Renders the block border into the frame and returns an inner frame for content.
    /// - Parameter frame: The frame to render borders into.
    /// - Returns: A sub-frame representing the inner content area.
    public func render(into frame: inout Frame) -> Frame {
        let width = frame.rect.width
        let height = frame.rect.height

        let hasTop = borders.contains(.top)
        let hasBottom = borders.contains(.bottom)
        let hasLeft = borders.contains(.left)
        let hasRight = borders.contains(.right)

        let topSize = hasTop ? 1 : 0
        let bottomSize = hasBottom ? 1 : 0
        let leftSize = hasLeft ? 1 : 0
        let rightSize = hasRight ? 1 : 0

        // Draw top border
        if hasTop {
            guard let hChar = boxDrawing.horizontal.first else { return frame }
            for x in leftSize..<(width - rightSize) {
                frame.setCell(x: x, y: 0, cell: Cell(character: hChar))
            }
        }

        // Draw bottom border
        if hasBottom {
            guard let hChar = boxDrawing.horizontal.first else { return frame }
            for x in leftSize..<(width - rightSize) {
                frame.setCell(x: x, y: height - 1, cell: Cell(character: hChar))
            }
        }

        // Draw left border
        if hasLeft {
            guard let vChar = boxDrawing.vertical.first else { return frame }
            for y in topSize..<(height - bottomSize) {
                frame.setCell(x: 0, y: y, cell: Cell(character: vChar))
            }
        }

        // Draw right border
        if hasRight {
            guard let vChar = boxDrawing.vertical.first else { return frame }
            for y in topSize..<(height - bottomSize) {
                frame.setCell(x: width - 1, y: y, cell: Cell(character: vChar))
            }
        }

        // Draw corners
        if hasTop && hasLeft, let ch = boxDrawing.topLeft.first {
            frame.setCell(x: 0, y: 0, cell: Cell(character: ch))
        }
        if hasTop && hasRight, let ch = boxDrawing.topRight.first {
            frame.setCell(x: width - 1, y: 0, cell: Cell(character: ch))
        }
        if hasBottom && hasLeft, let ch = boxDrawing.bottomLeft.first {
            frame.setCell(x: 0, y: height - 1, cell: Cell(character: ch))
        }
        if hasBottom && hasRight, let ch = boxDrawing.bottomRight.first {
            frame.setCell(x: width - 1, y: height - 1, cell: Cell(character: ch))
        }

        // Draw title in top border
        if let title = title, hasTop {
            let innerWidth = width - leftSize - rightSize
            guard innerWidth > 0 else {
                return computeInnerFrame(frame: frame, leftSize: leftSize, topSize: topSize, rightSize: rightSize, bottomSize: bottomSize)
            }

            let titleWidth = UnicodeWidth.displayWidth(title)
            let displayTitle: String
            if titleWidth > innerWidth {
                // Truncate title to fit
                var truncated = ""
                var currentWidth = 0
                for ch in title {
                    let charWidth = UnicodeWidth.width(of: ch)
                    if currentWidth + charWidth > innerWidth { break }
                    truncated.append(ch)
                    currentWidth += charWidth
                }
                displayTitle = truncated
            } else {
                displayTitle = title
            }

            let displayTitleWidth = UnicodeWidth.displayWidth(displayTitle)
            let titleX: Int
            switch titleAlignment {
            case .left:
                titleX = leftSize + min(1, innerWidth - displayTitleWidth)
            case .center:
                titleX = leftSize + max(0, (innerWidth - displayTitleWidth) / 2)
            case .right:
                titleX = leftSize + max(0, innerWidth - displayTitleWidth - 1)
            }

            frame.writeText(displayTitle, x: titleX, y: 0)
        }

        return computeInnerFrame(frame: frame, leftSize: leftSize, topSize: topSize, rightSize: rightSize, bottomSize: bottomSize)
    }

    private func computeInnerFrame(frame: Frame, leftSize: Int, topSize: Int, rightSize: Int, bottomSize: Int) -> Frame {
        let innerX = frame.rect.x + leftSize
        let innerY = frame.rect.y + topSize
        let innerWidth = max(0, frame.rect.width - leftSize - rightSize)
        let innerHeight = max(0, frame.rect.height - topSize - bottomSize)
        let innerRect = Rect(x: innerX, y: innerY, width: innerWidth, height: innerHeight)
        return frame.subFrame(innerRect)
    }
}
