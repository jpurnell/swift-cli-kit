// CalendarView.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A calendar widget that renders a single month grid with day names, numbers, and optional highlights.
///
/// ```swift
/// var frame = Frame(
///     buffer: CellBuffer(width: 40, height: 10),
///     rect: Rect(x: 0, y: 0, width: 40, height: 10)
/// )
/// let cal = CalendarView(year: 2026, month: 4, selectedDay: 15)
/// cal.render(into: &frame)
/// ```
public struct CalendarView: Sendable {
    /// The year to display.
    public var year: Int
    /// The month to display (1-12).
    public var month: Int
    /// The currently selected day, or `nil` for no selection.
    public var selectedDay: Int?
    /// A set of highlighted day numbers.
    public var highlightedDays: Set<Int>
    /// The style for the selected day.
    public var selectedStyle: CellStyle
    /// The style for highlighted days.
    public var highlightStyle: CellStyle
    /// Whether to show ISO week numbers in the left column.
    public var showWeekNumbers: Bool

    /// Creates a calendar view widget.
    /// - Parameters:
    ///   - year: The year.
    ///   - month: The month (1-12).
    ///   - selectedDay: The selected day (default: nil).
    ///   - highlightedDays: Days to highlight (default: empty).
    ///   - selectedStyle: Style for the selected day (default: reverse video).
    ///   - highlightStyle: Style for highlighted days (default: bold).
    ///   - showWeekNumbers: Whether to show week numbers (default: false).
    public init(
        year: Int,
        month: Int,
        selectedDay: Int? = nil,
        highlightedDays: Set<Int> = [],
        selectedStyle: CellStyle = CellStyle(attributes: [.reverse]),
        highlightStyle: CellStyle = CellStyle(attributes: [.bold]),
        showWeekNumbers: Bool = false
    ) {
        self.year = year
        self.month = month
        self.selectedDay = selectedDay
        self.highlightedDays = highlightedDays
        self.selectedStyle = selectedStyle
        self.highlightStyle = highlightStyle
        self.showWeekNumbers = showWeekNumbers
    }

    /// Renders this calendar into the given frame.
    ///
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        let calendar = Foundation.Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components) else { return }
        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sunday
        guard let daysRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return }
        let daysInMonth = daysRange.count

        let dayHeaders = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let colWidth = 4
        let weekNumOffset = showWeekNumbers ? 4 : 0

        // Row 0: day-of-week headers
        if showWeekNumbers {
            frame.writeText("Wk", x: 0, y: 0)
        }
        for (i, header) in dayHeaders.enumerated() {
            frame.writeText(header, x: weekNumOffset + i * colWidth, y: 0)
        }

        // Compute starting offset (Sunday = 0)
        let startOffset = ((weekday - calendar.firstWeekday) + 7) % 7

        // Render day numbers
        for day in 1...daysInMonth {
            let gridPosition = startOffset + day - 1
            let col = gridPosition % 7
            let row = gridPosition / 7 + 1 // +1 for header row

            let dayStr = day < 10 ? " \(day)" : "\(day)"

            // Determine style
            let style: CellStyle
            if let sel = selectedDay, sel == day {
                style = selectedStyle
            } else if highlightedDays.contains(day) {
                style = highlightStyle
            } else {
                style = CellStyle()
            }

            let xPos = weekNumOffset + col * colWidth
            frame.writeText(
                dayStr,
                x: xPos, y: row,
                fg: style.fg, bg: style.bg, attributes: style.attributes
            )

            // Week numbers: render at the start of each row
            if showWeekNumbers && col == 0 {
                guard let dayDate = calendar.date(
                    byAdding: .day, value: day - 1, to: firstOfMonth
                ) else { continue }
                let weekNum = calendar.component(.weekOfYear, from: dayDate)
                let wnStr = weekNum < 10 ? " \(weekNum)" : "\(weekNum)"
                frame.writeText(wnStr, x: 0, y: row)
            }
        }
    }
}

// MARK: - AccessibleWidget

extension CalendarView: AccessibleWidget {
    /// An accessibility label describing the calendar view, including the displayed month, year, and selected date.
    public var accessibilityLabel: AccessibilityLabel {
        let monthNames = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        let monthName = (month >= 1 && month <= 12) ? monthNames[month - 1] : "Unknown"
        var label = "\(monthName) \(year)"
        if let day = selectedDay { label += ", selected day \(day)" }
        return AccessibilityLabel(
            role: .calendar,
            label: label,
            hint: "Arrow keys to navigate days"
        )
    }
}
