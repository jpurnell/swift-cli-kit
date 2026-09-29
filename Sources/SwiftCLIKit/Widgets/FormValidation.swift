// FormValidation.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// A validation rule that can be applied to a string value.
///
/// Rules are composable: apply multiple rules to a single field and
/// the first failure short-circuits.
///
/// ```swift
/// let rules: [ValidationRule] = [.required, .minLength(3)]
/// let error = rules.lazy.compactMap { $0.validate("") }.first
/// // error == "This field is required"
/// ```
public enum ValidationRule: Sendable {
    /// The value must not be empty.
    case required
    /// The value must have at least the given number of characters.
    case minLength(Int)
    /// The value must have at most the given number of characters.
    case maxLength(Int)
    /// The value must match the given regex pattern string.
    case pattern(String)
    /// A custom validation closure. Returns an error message or nil.
    case custom(@Sendable (String) -> String?)

    /// Validate a string value against this rule.
    /// - Parameter value: The string to validate.
    /// - Returns: An error message if validation fails, or nil if valid.
    public func validate(_ value: String) -> String? {
        switch self {
        case .required:
            guard !value.trimmingCharacters(in: .whitespaces).isEmpty else {
                return "This field is required"
            }
            return nil

        case .minLength(let min):
            guard value.count >= min else {
                return "Must be at least \(min) characters"
            }
            return nil

        case .maxLength(let max):
            guard value.count <= max else {
                return "Must be at most \(max) characters"
            }
            return nil

        case .pattern(let regex):
            do {
                let expression = try NSRegularExpression(pattern: regex)
                let range = NSRange(value.startIndex..., in: value)
                guard expression.firstMatch(in: value, range: range) != nil else {
                    return "Does not match required pattern"
                }
                return nil
            } catch { // silent: error surfaced to caller as validation failure message
                return "Invalid validation pattern: \(error.localizedDescription)"
            }

        case .custom(let closure):
            return closure(value)
        }
    }
}

/// Utility for validating values against multiple rules.
public struct FormValidator: Sendable {
    /// Validate a value against multiple rules. Returns the first error, or nil.
    /// - Parameters:
    ///   - value: The string to validate.
    ///   - rules: The validation rules to apply in order.
    /// - Returns: The first error message encountered, or nil if all rules pass.
    public static func validate(
        _ value: String,
        rules: [ValidationRule]
    ) -> String? {
        guard !rules.isEmpty else { return nil }
        for rule in rules {
            if let error = rule.validate(value) {
                return error
            }
        }
        return nil
    }

    /// Validate all fields. Returns a dictionary of fieldID to error message.
    /// - Parameter fields: Tuples of (id, value, rules) for each field.
    /// - Returns: A dictionary mapping field IDs to their first validation error.
    public static func validateAll(
        _ fields: [(id: String, value: String, rules: [ValidationRule])]
    ) -> [String: String] {
        var errors: [String: String] = [:]
        for field in fields {
            if let error = validate(field.value, rules: field.rules) {
                errors[field.id] = error
            }
        }
        return errors
    }
}
