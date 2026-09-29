// Paragraph.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A text widget that renders a string into a ``Frame`` with alignment and wrapping options.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let para = Paragraph(text: "Hello, world!", alignment: .center, wrap: true)
/// para.render(into: &frame, fg: .ansi8(.green))
/// ```
public struct Paragraph: Sendable {
    /// Text alignment within the frame.
    public enum Alignment: Sendable, Equatable, Hashable {
        /// Left-aligned (default).
        case left
        /// Centered.
        case center
        /// Right-aligned.
        case right
    }

    /// The text content to render.
    public var text: String
    /// How to align text within the frame.
    public var alignment: Alignment
    /// Whether to wrap text at the frame boundary.
    public var wrap: Bool

    /// Creates a paragraph widget.
    /// - Parameters:
    ///   - text: The text to display.
    ///   - alignment: Text alignment (default: left).
    ///   - wrap: Whether to word-wrap (default: true).
    public init(text: String, alignment: Alignment = .left, wrap: Bool = true) {
        self.text = text
        self.alignment = alignment
        self.wrap = wrap
    }

    /// A wrapped visual line paired with the index of the logical line it came from.
    private struct WrappedLine {
        let text: String
        let sourceLine: Int
    }

    /// The logical lines of the source text, split only on explicit newlines.
    ///
    /// This is the pre-wrap content — the text as it would be copied without the
    /// spurious line breaks introduced by fixed-width rendering. Returns an empty
    /// array for empty text.
    public var logicalLines: [String] {
        guard !text.isEmpty else { return [] }
        return text.lines
    }

    /// Computes the visual lines this paragraph produces when wrapped to a width.
    ///
    /// Mirrors the wrapping used by ``render(into:fg:bg:)`` so callers can copy or
    /// measure the exact text that will be displayed.
    /// - Parameter width: The wrapping width in columns.
    /// - Returns: The wrapped visual lines, in render order.
    public func wrappedLines(width: Int) -> [String] {
        computeWrappedLines(frameWidth: width).map(\.text)
    }

    /// Maps each visual line to the index of the logical line it originated from.
    ///
    /// The result is parallel to ``wrappedLines(width:)``; entry `i` gives the
    /// ``logicalLines`` index that visual row `i` belongs to. Use it to recover
    /// the full logical line under a clicked or selected row for copying.
    /// - Parameter width: The wrapping width in columns.
    /// - Returns: A logical-line index for each visual line.
    public func sourceLineMap(width: Int) -> [Int] {
        computeWrappedLines(frameWidth: width).map(\.sourceLine)
    }

    /// Wraps the source text to the given width, tracking each visual line's origin.
    private func computeWrappedLines(frameWidth: Int) -> [WrappedLine] {
        guard !text.isEmpty, frameWidth > 0 else { return [] }

        // Split on explicit newlines first, then process each segment
        let explicitLines = text.lines

        var lines: [WrappedLine] = []

        for (sourceIndex, segment) in explicitLines.enumerated() {
            let words = segment.split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)

            if words.isEmpty {
                // Empty segment from consecutive newlines — preserve as blank line
                lines.append(WrappedLine(text: "", sourceLine: sourceIndex))
                continue
            }

            if wrap {
                var currentLine = ""
                var currentWidth = 0

                for word in words {
                    let wordWidth = UnicodeWidth.displayWidth(word)
                    if currentLine.isEmpty {
                        // First word on line -- always add it even if it exceeds width
                        currentLine = word
                        currentWidth = wordWidth
                    } else {
                        let neededWidth = currentWidth + 1 + wordWidth
                        if neededWidth <= frameWidth {
                            currentLine += " " + word
                            currentWidth = neededWidth
                        } else {
                            lines.append(WrappedLine(text: currentLine, sourceLine: sourceIndex))
                            currentLine = word
                            currentWidth = wordWidth
                        }
                    }
                }
                if !currentLine.isEmpty {
                    lines.append(WrappedLine(text: currentLine, sourceLine: sourceIndex))
                }
            } else {
                // No wrap: single line per segment, truncated to frame width
                var currentLine = ""
                var currentWidth = 0

                for word in words {
                    let wordWidth = UnicodeWidth.displayWidth(word)
                    if currentLine.isEmpty {
                        if wordWidth <= frameWidth {
                            currentLine = word
                            currentWidth = wordWidth
                        } else {
                            // First word too long, truncate character-by-character
                            for ch in word {
                                let charWidth = UnicodeWidth.width(of: ch)
                                if currentWidth + charWidth > frameWidth { break }
                                currentLine.append(ch)
                                currentWidth += charWidth
                            }
                            break
                        }
                    } else {
                        let neededWidth = currentWidth + 1 + wordWidth
                        if neededWidth <= frameWidth {
                            currentLine += " " + word
                            currentWidth = neededWidth
                        } else {
                            // Word doesn't fit with space -- fill remaining space char by char
                            let remaining = frameWidth - currentWidth
                            if remaining > 0 {
                                for ch in word {
                                    let charWidth = UnicodeWidth.width(of: ch)
                                    if currentWidth + charWidth > frameWidth { break }
                                    currentLine.append(ch)
                                    currentWidth += charWidth
                                }
                            }
                            break
                        }
                    }
                }
                lines.append(WrappedLine(text: currentLine, sourceLine: sourceIndex))
            }
        }

        return lines
    }

    /// Renders this paragraph into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - fg: Foreground color.
    ///   - bg: Background color.
    public func render(into frame: inout Frame, fg: Color = .default, bg: Color = .default) {
        guard !text.isEmpty else { return }

        let frameWidth = frame.rect.width
        let frameHeight = frame.rect.height
        guard frameWidth > 0, frameHeight > 0 else { return }

        let lines = computeWrappedLines(frameWidth: frameWidth).map(\.text)

        for (lineIndex, line) in lines.enumerated() {
            guard lineIndex < frameHeight else { break }
            let lineWidth = UnicodeWidth.displayWidth(line)
            let padding: Int
            switch alignment {
            case .left:
                padding = 0
            case .center:
                padding = max(0, (frameWidth - lineWidth) / 2)
            case .right:
                padding = max(0, frameWidth - lineWidth)
            }
            frame.writeText(line, x: padding, y: lineIndex, fg: fg, bg: bg)
        }
    }
}
