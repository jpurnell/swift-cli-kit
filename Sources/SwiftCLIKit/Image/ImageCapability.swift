// ImageCapability.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Supported terminal image protocols.
///
/// Each case corresponds to a different escape-sequence format for displaying
/// inline images in a terminal emulator.
///
/// ```swift
/// let cap = ImageCapabilityDetector.detect()
/// switch cap {
/// case .kitty:  print("Kitty graphics protocol available")
/// case .sixel:  print("Sixel graphics available")
/// case .iterm2: print("iTerm2 inline images available")
/// case .none:   print("No image protocol — use ASCII art fallback")
/// }
/// ```
public enum ImageCapability: String, Sendable, CaseIterable {
    /// Kitty graphics protocol (Kitty, Ghostty, WezTerm).
    case kitty
    /// Sixel graphics protocol (xterm -ti 340, mlterm, foot).
    case sixel
    /// iTerm2 inline image protocol (iTerm2, WezTerm).
    case iterm2
    /// No image protocol detected — use ASCII art fallback.
    case none
}

/// Detects the best available image protocol from environment variables.
///
/// Detection checks in priority order: explicit override, Kitty, iTerm2, Sixel, none.
/// Set the `SWIFTCLIKIT_IMAGE_PROTOCOL` environment variable to force a specific protocol.
public enum ImageCapabilityDetector {

    /// Detect the best available image protocol from the current process environment.
    /// - Returns: The detected ``ImageCapability``.
    public static func detect() -> ImageCapability {
        detect(environment: ProcessInfo.processInfo.environment)
    }

    /// Detect capability from a specific set of environment variables.
    ///
    /// Useful for testing with controlled environments.
    /// - Parameter environment: A dictionary of environment variable names to values.
    /// - Returns: The detected ``ImageCapability``.
    public static func detect(environment: [String: String]) -> ImageCapability {
        // Explicit override takes priority
        if let override = environment["SWIFTCLIKIT_IMAGE_PROTOCOL"] {
            let lowered = override.lowercased()
            switch lowered {
            case "kitty":  return .kitty
            case "sixel":  return .sixel
            case "iterm2": return .iterm2
            case "none":   return .none
            default:       break
            }
        }

        // Kitty detection: TERM_PROGRAM or KITTY_WINDOW_ID
        let termProgram = environment["TERM_PROGRAM"]?.lowercased() ?? ""
        if termProgram == "kitty" || termProgram == "ghostty" || termProgram == "wezterm" {
            return .kitty
        }
        if environment["KITTY_WINDOW_ID"] != nil {
            return .kitty
        }

        // iTerm2 detection: TERM_PROGRAM or ITERM_SESSION_ID
        if termProgram == "iterm.app" || termProgram == "iterm2" {
            return .iterm2
        }
        if environment["ITERM_SESSION_ID"] != nil {
            return .iterm2
        }

        // Sixel detection: SIXEL_SUPPORT env var
        if environment["SIXEL_SUPPORT"] != nil {
            return .sixel
        }

        return .none
    }
}
