// Form+Node.swift
// SwiftGUIKit
//
// Projects the SwiftCLIKit `Form` composite into the semantic scene graph via
// reconstruct-and-call. The legacy render path is untouched.

import SwiftCLIKit

public extension Form {
    /// Projects this form into a semantic ``Node``.
    /// - Parameter color: The base text color role (default: ``ColorRole/label``).
    /// - Returns: A ``Node/form(fields:focusedIndex:errors:color:)`` node.
    func node(color: ColorRole = .label) -> Node {
        .form(
            fields: fields.map { FormFieldData(id: $0.id, label: $0.label, value: $0.value) },
            focusedIndex: focusedFieldIndex,
            errors: errors,
            color: color
        )
    }
}
