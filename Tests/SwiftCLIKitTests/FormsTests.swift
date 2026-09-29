// FormsTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Forms")
struct FormsTests {

    private func makeFrame(width: Int, height: Int) -> Frame {
        let buf = CellBuffer(width: width, height: height)
        return Frame(buffer: buf, rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func extractRow(_ frame: Frame, y: Int, width: Int) -> String {
        let buf = frame.cellBuffer
        return String((0..<width).map { buf[$0, y].character })
    }

    // MARK: - TextField

    @Test("TextField renders placeholder when empty")
    func textFieldPlaceholder() {
        let field = TextField(label: "", placeholder: "Enter name")
        var frame = makeFrame(width: 30, height: 3)
        field.render(into: &frame, focused: false)
        let row = extractRow(frame, y: 1, width: 30)
        #expect(row.contains("Enter name"))
    }

    @Test("TextField renders text when filled")
    func textFieldFilled() {
        let field = TextField(label: "", placeholder: "Enter name", text: "Alice")
        var frame = makeFrame(width: 30, height: 3)
        field.render(into: &frame, focused: false)
        let row = extractRow(frame, y: 1, width: 30)
        #expect(row.contains("Alice"))
    }

    @Test("TextField focused shows bold border attributes")
    func textFieldFocused() {
        let field = TextField(label: "", placeholder: "")
        var frame = makeFrame(width: 20, height: 3)
        field.render(into: &frame, focused: true)
        let buf = frame.cellBuffer
        // The border cell should have bold attribute when focused
        #expect(buf[0, 0].attributes.contains(.bold))
    }

    @Test("TextField handleKey changes text")
    func textFieldHandleKey() {
        var field = TextField(label: "Name")
        let result = field.handleKey(.character("A"))
        #expect(result == .changed("A"))
        #expect(field.text == "A")
    }

    @Test("TextField enter submits")
    func textFieldSubmit() {
        var field = TextField(label: "Name", text: "Hello")
        let result = field.handleKey(.enter)
        #expect(result == .submitted("Hello"))
    }

    // MARK: - Checkbox

    @Test("Checkbox toggle flips state")
    func checkboxToggle() {
        var cb = Checkbox(label: "Agree")
        #expect(!cb.isChecked)
        cb.toggle()
        #expect(cb.isChecked)
        cb.toggle()
        #expect(!cb.isChecked)
    }

    @Test("Checkbox render shows [x] when checked and [ ] when unchecked")
    func checkboxRender() {
        let checked = Checkbox(label: "On", isChecked: true)
        var frame1 = makeFrame(width: 20, height: 1)
        checked.render(into: &frame1, focused: false)
        let row1 = extractRow(frame1, y: 0, width: 20)
        #expect(row1.contains("[x]"))

        let unchecked = Checkbox(label: "Off", isChecked: false)
        var frame2 = makeFrame(width: 20, height: 1)
        unchecked.render(into: &frame2, focused: false)
        let row2 = extractRow(frame2, y: 0, width: 20)
        #expect(row2.contains("[ ]"))
    }

    // MARK: - RadioGroup

    @Test("RadioGroup selection changes on selectNext")
    func radioGroupSelection() {
        var group = RadioGroup(options: ["A", "B", "C"])
        #expect(group.selectedIndex == 0)
        group.selectNext()
        #expect(group.selectedIndex == 1)
        group.selectNext()
        #expect(group.selectedIndex == 2)
        group.selectNext()
        #expect(group.selectedIndex == 0) // wraps
    }

    @Test("RadioGroup render shows filled and empty indicators")
    func radioGroupRender() {
        let group = RadioGroup(options: ["X", "Y"], selectedIndex: 0)
        var frame = makeFrame(width: 20, height: 2)
        group.render(into: &frame, focused: false)
        let row0 = extractRow(frame, y: 0, width: 20)
        let row1 = extractRow(frame, y: 1, width: 20)
        // Selected uses filled circle, unselected uses empty
        #expect(row0.contains("\u{25CF}"))
        #expect(row1.contains("( )"))
    }

    // MARK: - Dropdown

    @Test("Dropdown expanded shows all options, collapsed shows selected")
    func dropdownExpandCollapse() {
        var dd = Dropdown(label: "Size", options: ["S", "M", "L"])

        // Collapsed: should show selected value
        var frame1 = makeFrame(width: 30, height: 5)
        dd.render(into: &frame1, focused: false)
        let row0 = extractRow(frame1, y: 0, width: 30)
        #expect(row0.contains("S"))
        // No option list visible when collapsed
        let row1 = extractRow(frame1, y: 1, width: 30)
        #expect(!row1.contains("M"))

        // Expanded
        dd.toggle()
        #expect(dd.isExpanded)
        var frame2 = makeFrame(width: 30, height: 5)
        dd.render(into: &frame2, focused: false)
        let eRow1 = extractRow(frame2, y: 1, width: 30)
        let eRow2 = extractRow(frame2, y: 2, width: 30)
        #expect(eRow1.contains("S"))
        #expect(eRow2.contains("M"))
    }

    // MARK: - FormValidation

    @Test("ValidationRule.required on empty returns error, on filled returns nil")
    func validationRequired() {
        let rule = ValidationRule.required
        #expect(rule.validate("") == "This field is required")
        #expect(rule.validate("  ") == "This field is required")
        #expect(rule.validate("hello") == nil)
    }

    @Test("ValidationRule.minLength(3) on 'ab' returns error")
    func validationMinLength() {
        let rule = ValidationRule.minLength(3)
        #expect(rule.validate("ab") == "Must be at least 3 characters")
        #expect(rule.validate("abc") == nil)
        #expect(rule.validate("abcd") == nil)
    }

    @Test("ValidationRule.maxLength(5) on long string returns error")
    func validationMaxLength() {
        let rule = ValidationRule.maxLength(5)
        #expect(rule.validate("abcdef") == "Must be at most 5 characters")
        #expect(rule.validate("abcde") == nil)
    }

    @Test("ValidationRule.pattern matches regex")
    func validationPattern() {
        let rule = ValidationRule.pattern("^[0-9]+$")
        #expect(rule.validate("abc") == "Does not match required pattern")
        #expect(rule.validate("123") == nil)
    }

    @Test("FormValidator.validateAll returns errors for failing fields")
    func validatorAll() {
        let errors = FormValidator.validateAll([
            (id: "name", value: "", rules: [.required]),
            (id: "email", value: "test@test.com", rules: [.required]),
        ])
        #expect(errors.count == 1)
        #expect(errors["name"] == "This field is required")
        #expect(errors["email"] == nil)
    }

    // MARK: - Form

    @Test("Form.validate returns false when required field is empty")
    func formValidate() {
        var form = Form(fields: [
            Form.Field(id: "name", label: "Name", value: "", validation: [.required]),
            Form.Field(id: "age", label: "Age", value: "25", validation: []),
        ])
        let valid = form.validate()
        #expect(!valid)
        #expect(form.errors["name"] == "This field is required")
    }

    @Test("Form.focusNext cycles through fields")
    func formFocusCycle() {
        var form = Form(fields: [
            Form.Field(id: "a", label: "A"),
            Form.Field(id: "b", label: "B"),
            Form.Field(id: "c", label: "C"),
        ])
        #expect(form.focusedFieldIndex == 0)
        form.focusNext()
        #expect(form.focusedFieldIndex == 1)
        form.focusNext()
        #expect(form.focusedFieldIndex == 2)
        form.focusNext()
        #expect(form.focusedFieldIndex == 0) // wraps
    }

    @Test("Form.focusPrevious wraps at start")
    func formFocusPrevious() {
        var form = Form(fields: [
            Form.Field(id: "a", label: "A"),
            Form.Field(id: "b", label: "B"),
        ])
        #expect(form.focusedFieldIndex == 0)
        form.focusPrevious()
        #expect(form.focusedFieldIndex == 1) // wraps to last
    }

    @Test("Form.value(forField:) returns value or nil")
    func formValueForField() {
        let form = Form(fields: [
            Form.Field(id: "name", label: "Name", value: "Alice"),
        ])
        #expect(form.value(forField: "name") == "Alice")
        #expect(form.value(forField: "nonexistent") == nil)
    }

    // MARK: - TextArea

    @Test("TextArea enter creates new line")
    func textAreaEnter() {
        var area = TextArea(text: "Hello")
        let result = area.handleKey(.enter)
        #expect(result == .changed("Hello\n"))
        #expect(area.lines.count == 2)
        #expect(area.cursorRow == 1)
    }

    @Test("TextArea text getter joins lines")
    func textAreaJoin() {
        let area = TextArea(text: "Line1\nLine2\nLine3")
        #expect(area.text == "Line1\nLine2\nLine3")
        #expect(area.lines.count == 3)
    }

    @Test("TextArea arrow keys navigate between lines")
    func textAreaNavigation() {
        var area = TextArea(text: "AAA\nBBB")
        // Cursor starts at end of last line
        #expect(area.cursorRow == 1)
        _ = area.handleKey(.arrowUp)
        #expect(area.cursorRow == 0)
        _ = area.handleKey(.arrowDown)
        #expect(area.cursorRow == 1)
    }
}
