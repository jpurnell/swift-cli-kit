// FormControls+Node.swift
// SwiftGUIKit
//
// Projects the Dropdown, TextField, TextArea, and CalendarView widgets into the
// semantic scene graph. All are reconstruct-and-call ports; legacy render paths
// are untouched.

import SwiftCLIKit

public extension Dropdown {
    /// Projects this dropdown into a semantic ``Node`` (resting state).
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .dropdown(label: label, options: options, selectedIndex: selectedIndex,
                  isExpanded: isExpanded, id: id, color: color)
    }
}

public extension TextField {
    /// Projects this text field into a semantic ``Node`` (resting state).
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .textField(label: label, placeholder: placeholder, text: text, id: id, color: color)
    }
}

public extension TextArea {
    /// Projects this text area into a semantic ``Node`` (resting state).
    /// - Parameter color: The text color role (default: ``ColorRole/label``).
    func node(id: String = "", color: ColorRole = .label) -> Node {
        .textArea(text: text, scrollOffset: scrollOffset, id: id, color: color)
    }
}

public extension CalendarView {
    /// Projects this calendar into a semantic ``Node``.
    /// - Parameter color: The base text color role (default: ``ColorRole/label``).
    func node(color: ColorRole = .label) -> Node {
        .calendar(year: year, month: month, selectedDay: selectedDay,
                  highlightedDays: highlightedDays, showWeekNumbers: showWeekNumbers, color: color)
    }
}
