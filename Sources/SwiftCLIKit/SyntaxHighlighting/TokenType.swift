// TokenType.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// The semantic type of a syntax token for highlighting.
///
/// Each token type maps to a color and optional attributes via ``SyntaxTheme``.
public enum TokenType: String, Sendable, CaseIterable {
    case keyword, type, string, number, comment, decorator
    case `operator`, function, variable, plain
}
