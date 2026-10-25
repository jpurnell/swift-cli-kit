// Form.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// The outcome of a key press handled by a ``Form``.
public enum FormResult: Sendable, Equatable {
    /// A field's value changed.
    case fieldChanged(fieldID: String, value: String)
    /// The form was submitted (Enter on last field).
    case submitted
    /// The form was cancelled (Escape).
    case cancelled
    /// Focus moved to a new field.
    case focusChanged(String)
    /// The key was not consumed by the form.
    case unhandled
}

/// A container widget that composes form fields with layout, focus management,
/// and validation.
///
/// ```swift
/// var form = Form(fields: [
///     Form.Field(id: "name", label: "Name", value: "", validation: [.required]),
///     Form.Field(id: "email", label: "Email", value: "", validation: [.required]),
/// ])
/// let valid = form.validate()
/// ```
public struct Form: Sendable {
    /// A single field in the form.
    public struct Field: Sendable {
        /// Unique identifier for this field.
        public var id: String
        /// The display label.
        public var label: String
        /// The current string value.
        public var value: String
        /// Validation rules for this field.
        public var validation: [ValidationRule]

        /// Creates a form field.
        /// - Parameters:
        ///   - id: Unique field identifier.
        ///   - label: The display label.
        ///   - value: The initial value.
        ///   - validation: Validation rules to apply.
        public init(
            id: String,
            label: String,
            value: String = "",
            validation: [ValidationRule] = []
        ) {
            self.id = id
            self.label = label
            self.value = value
            self.validation = validation
        }
    }

    /// The form's fields.
    public var fields: [Field]
    /// The index of the currently focused field.
    public var focusedFieldIndex: Int
    /// Validation errors keyed by field ID.
    public var errors: [String: String]

    /// Creates a form widget.
    /// - Parameter fields: The form fields.
    public init(fields: [Field]) {
        self.fields = fields
        self.focusedFieldIndex = fields.isEmpty ? 0 : 0
        self.errors = [:]
    }

    /// Validate all fields. Populates ``errors`` and returns true if all valid.
    /// - Returns: `true` when every field passes validation.
    public mutating func validate() -> Bool {
        errors = [:]
        for field in fields {
            if let error = FormValidator.validate(field.value, rules: field.validation) {
                errors[field.id] = error
            }
        }
        return errors.isEmpty
    }

    /// Move focus to the next field (wraps around).
    public mutating func focusNext() {
        guard !fields.isEmpty else { return }
        focusedFieldIndex = (focusedFieldIndex + 1) % fields.count
    }

    /// Move focus to the previous field (wraps around).
    public mutating func focusPrevious() {
        guard !fields.isEmpty else { return }
        focusedFieldIndex = (focusedFieldIndex - 1 + fields.count) % fields.count
    }

    /// Get the string value of a field by ID.
    /// - Parameter id: The field identifier.
    /// - Returns: The field's value, or nil if the ID is not found.
    public func value(forField id: String) -> String? {
        guard let field = fields.first(where: { $0.id == id }) else {
            return nil
        }
        return field.value
    }

    /// Renders the form into the given frame.
    /// - Parameter frame: The frame to render into.
    public func render(into frame: inout Frame) {
        guard frame.rect.width > 0 else { return }

        var row = 0
        for (index, field) in fields.enumerated() {
            let isFocused = index == focusedFieldIndex
            let attrs: CellAttributes = isFocused ? .bold : []

            // Label
            frame.writeText(field.label, x: 0, y: row, attributes: attrs)

            // Value
            let labelWidth = field.label.count + 2
            frame.writeText(field.value, x: labelWidth, y: row, attributes: attrs)

            // Error
            if let error = errors[field.id] {
                row += 1
                frame.writeText(
                    error,
                    x: labelWidth, y: row,
                    fg: .ansi8(.red)
                )
            }

            row += 2
        }
    }
}
