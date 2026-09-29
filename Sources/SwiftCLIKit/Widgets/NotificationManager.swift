// NotificationManager.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Manages active toasts: push, dismiss, expire, and enforce max-visible.
///
/// ```swift
/// var manager = NotificationManager()
/// manager.push(Toast(message: "Saved", severity: .success))
/// ```
public struct NotificationManager: Sendable {
    /// Screen position for the notification overlay area.
    public enum Position: Sendable, Equatable {
        case topRight
        case topLeft
        case bottomRight
        case bottomLeft
    }

    /// The active toasts (newest last).
    public var toasts: [Toast]
    /// Maximum number of visible toasts.
    public var maxVisible: Int
    /// Where toasts are rendered on screen.
    public var position: Position

    /// Creates a notification manager.
    /// - Parameters:
    ///   - maxVisible: Maximum visible toasts.
    ///   - position: Screen position for the toast stack.
    public init(maxVisible: Int = 5, position: Position = .bottomRight) {
        self.toasts = []
        self.maxVisible = max(maxVisible, 1)
        self.position = position
    }

    /// Add a toast. If count exceeds maxVisible, the oldest toast is removed.
    /// - Parameter toast: The toast to push.
    public mutating func push(_ toast: Toast) {
        toasts.append(toast)
        while toasts.count > maxVisible {
            toasts.removeFirst()
        }
    }

    /// Dismiss a specific toast by ID. No-op if ID not found.
    /// - Parameter id: The toast identifier to remove.
    public mutating func dismiss(id: String) {
        guard let index = toasts.firstIndex(where: { $0.id == id }) else { return }
        toasts.remove(at: index)
    }

    /// Remove all toasts that have expired relative to the given time.
    /// - Parameter now: The reference time.
    public mutating func expireOld(now: ContinuousClock.Instant) {
        toasts.removeAll { $0.isExpired(at: now) }
    }

    /// Whether there are no active toasts.
    public var isEmpty: Bool { toasts.count == 0 }

    /// Renders the notification toasts into the given frame.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - screenWidth: The total screen width.
    ///   - screenHeight: The total screen height.
    public func render(into frame: inout Frame, screenWidth: Int, screenHeight: Int) {
        guard !toasts.isEmpty else { return }

        let toastWidth = 40
        let toastHeight = 3

        let visibleToasts = Array(toasts.suffix(maxVisible))

        for (stackIndex, toast) in visibleToasts.enumerated() {
            let origin = toastOrigin(
                stackIndex: stackIndex,
                toastWidth: toastWidth,
                toastHeight: toastHeight,
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )

            let color = toast.severity.color

            // Draw border
            let box = BoxDrawing.unicode
            frame.writeText(box.topLeft, x: origin.x, y: origin.y, fg: color)
            for col in 1..<(toastWidth - 1) {
                frame.writeText(box.horizontal, x: origin.x + col, y: origin.y, fg: color)
            }
            frame.writeText(box.topRight, x: origin.x + toastWidth - 1, y: origin.y, fg: color)

            // Message row
            frame.writeText(box.vertical, x: origin.x, y: origin.y + 1, fg: color)
            let maxMsgLen = toastWidth - 4
            let displayMsg = String(toast.message.prefix(maxMsgLen))
            frame.writeText(" \(displayMsg)", x: origin.x + 1, y: origin.y + 1, fg: color)
            frame.writeText(box.vertical, x: origin.x + toastWidth - 1, y: origin.y + 1, fg: color)

            // Bottom border
            frame.writeText(box.bottomLeft, x: origin.x, y: origin.y + 2, fg: color)
            for col in 1..<(toastWidth - 1) {
                frame.writeText(box.horizontal, x: origin.x + col, y: origin.y + 2, fg: color)
            }
            frame.writeText(box.bottomRight, x: origin.x + toastWidth - 1, y: origin.y + 2, fg: color)
        }
    }

    /// Computes the origin for a toast at the given stack index.
    private func toastOrigin(
        stackIndex: Int,
        toastWidth: Int,
        toastHeight: Int,
        screenWidth: Int,
        screenHeight: Int
    ) -> (x: Int, y: Int) {
        let x: Int
        let y: Int

        switch position {
        case .bottomRight:
            x = max(screenWidth - toastWidth, 0)
            y = max(screenHeight - (toastHeight * (stackIndex + 1)), 0)
        case .bottomLeft:
            x = 0
            y = max(screenHeight - (toastHeight * (stackIndex + 1)), 0)
        case .topRight:
            x = max(screenWidth - toastWidth, 0)
            y = toastHeight * stackIndex
        case .topLeft:
            x = 0
            y = toastHeight * stackIndex
        }

        return (x: x, y: y)
    }
}
