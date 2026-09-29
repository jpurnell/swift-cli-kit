// ColorNegotiation.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Detects terminal color capability and produces ANSI escape sequences
/// for foreground and background colors, auto-downsampling when needed.
public enum ColorNegotiation {

    /// Queries environment variables to determine the best color capability.
    /// - Returns: The detected ``ColorCapability``.
    public static func detect() -> ColorCapability {
        let env = ProcessInfo.processInfo.environment

        // NO_COLOR set (any value) → no color
        guard env["NO_COLOR"] == nil else { return .none }

        // COLORTERM == "truecolor" or "24bit" → truecolor
        if let colorterm = env["COLORTERM"] {
            let lower = colorterm.lowercased()
            if lower == "truecolor" || lower == "24bit" {
                return .truecolor
            }
        }

        // Check TERM
        if let term = env["TERM"] {
            let lower = term.lowercased()

            // TERM contains "256color" → extended
            if lower.contains("256color") {
                return .extended
            }

            // TERM == "dumb" → none
            if lower == "dumb" {
                return .none
            }
        }

        // Default → basic
        return .basic
    }

    /// Returns an ANSI foreground escape sequence for the given color,
    /// downsampling automatically if the capability is too low.
    /// - Parameters:
    ///   - color: The color to render.
    ///   - capability: The terminal's color capability.
    /// - Returns: An escape string, or empty if capability is `.none`.
    public static func fgEscape(_ color: Color, capability: ColorCapability) -> String {
        guard capability != .none else { return "" }

        let resolved = color.downsampled(to: capability)

        switch resolved {
        case .defaultColor:
            return "\u{001B}[39m"
        case .ansi8(let ansiColor):
            return ANSICodes.fg(ansiColor)
        case .ansi256(let index):
            return ANSICodes.fg256(index)
        case .truecolor(let r, let g, let b):
            return ANSICodes.fgRGB(r, g, b)
        }
    }

    /// Returns an ANSI background escape sequence for the given color,
    /// downsampling automatically if the capability is too low.
    /// - Parameters:
    ///   - color: The color to render.
    ///   - capability: The terminal's color capability.
    /// - Returns: An escape string, or empty if capability is `.none`.
    public static func bgEscape(_ color: Color, capability: ColorCapability) -> String {
        guard capability != .none else { return "" }

        let resolved = color.downsampled(to: capability)

        switch resolved {
        case .defaultColor:
            return "\u{001B}[49m"
        case .ansi8(let ansiColor):
            return ANSICodes.bg(ansiColor)
        case .ansi256(let index):
            return ANSICodes.bg256(index)
        case .truecolor(let r, let g, let b):
            return ANSICodes.bgRGB(r, g, b)
        }
    }
}
