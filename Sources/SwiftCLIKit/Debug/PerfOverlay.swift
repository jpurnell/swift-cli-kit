// PerfOverlay.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A floating overlay that displays real-time performance metrics.
///
/// `PerfOverlay` renders as a small box in a corner of the terminal,
/// showing FPS, frame time, and cell count.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// var overlay = PerfOverlay(position: .topRight)
/// overlay.tracker.beginFrame()
/// overlay.tracker.endFrame()
/// overlay.isVisible = true
/// overlay.render(into: &frame)
/// ```
public struct PerfOverlay: Sendable {
    /// The performance tracker providing metrics.
    public var tracker: PerfTracker

    /// Where the overlay appears on screen.
    public var position: OverlayPosition

    /// Whether the overlay is currently visible.
    public var isVisible: Bool

    /// Screen corner for overlay placement.
    public enum OverlayPosition: Sendable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    /// Width of the overlay in columns.
    public static let overlayWidth: Int = 22

    /// Height of the overlay in rows.
    public static let overlayHeight: Int = 4

    /// Creates a new performance overlay.
    /// - Parameter position: The corner to place the overlay (default: top-right).
    public init(position: OverlayPosition = .topRight) {
        self.tracker = PerfTracker()
        self.position = position
        self.isVisible = false
    }

    /// Renders the overlay into the given frame.
    ///
    /// No-op if ``isVisible`` is `false`. When visible, writes a compact HUD
    /// showing FPS, average frame time, and diff cell count.
    ///
    /// - Parameter frame: The rendering surface to draw into.
    public func render(into frame: inout Frame) {
        guard isVisible else { return }

        let width = Self.overlayWidth
        let height = Self.overlayHeight
        guard frame.rect.width >= width, frame.rect.height >= height else { return }

        let originX: Int
        let originY: Int

        switch position {
        case .topLeft:
            originX = 0
            originY = 0
        case .topRight:
            originX = frame.rect.width - width
            originY = 0
        case .bottomLeft:
            originX = 0
            originY = frame.rect.height - height
        case .bottomRight:
            originX = frame.rect.width - width
            originY = frame.rect.height - height
        }

        // Background
        let bgCell = Cell(character: " ", bg: .ansi8(.black))
        for row in 0..<height {
            for col in 0..<width {
                frame.setCell(x: originX + col, y: originY + row, cell: bgCell)
            }
        }

        // FPS line
        let fpsValue = Int(tracker.currentFPS)
        let fpsLine = " FPS: \(fpsValue)"
        frame.writeText(
            String(fpsLine.prefix(width)),
            x: originX,
            y: originY,
            fg: .ansi8(.green),
            bg: .ansi8(.black)
        )

        // Frame time line
        let avgMs = durationToMs(tracker.averageFrameTime)
        let frameLine = " Frame: \(avgMs) ms"
        frame.writeText(
            String(frameLine.prefix(width)),
            x: originX,
            y: originY + 1,
            fg: .ansi8(.yellow),
            bg: .ansi8(.black)
        )

        // Cell count line
        let cellLine = " Cells: \(tracker.lastDiffCellCount)"
        frame.writeText(
            String(cellLine.prefix(width)),
            x: originX,
            y: originY + 2,
            fg: .ansi8(.cyan),
            bg: .ansi8(.black)
        )

        // Update/View line
        let updateMs = durationToMs(tracker.lastUpdateDuration)
        let viewMs = durationToMs(tracker.lastViewDuration)
        let phaseLine = " U:\(updateMs) V:\(viewMs) ms"
        frame.writeText(
            String(phaseLine.prefix(width)),
            x: originX,
            y: originY + 3,
            fg: .ansi8(.white),
            bg: .ansi8(.black)
        )
    }

    /// Converts a Duration to a millisecond string without String(format:).
    private func durationToMs(_ duration: Duration) -> String {
        let components = duration.components
        let totalNanoseconds = components.seconds * 1_000_000_000 + components.attoseconds / 1_000_000_000
        let ms = totalNanoseconds / 1_000_000
        let fractional = (totalNanoseconds % 1_000_000) / 100_000
        return "\(ms).\(fractional)"
    }
}
