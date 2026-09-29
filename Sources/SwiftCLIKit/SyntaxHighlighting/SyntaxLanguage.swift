// SyntaxLanguage.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

/// Supported programming languages for syntax highlighting.
///
/// Use ``detect(fileExtension:)`` or ``detect(filename:)`` to automatically
/// determine the language from a file path.
///
/// ```swift
/// let lang = SyntaxLanguage.detect(fileExtension: "swift")  // .swift
/// let lang2 = SyntaxLanguage.detect(filename: "main.py")    // .python
/// ```
public enum SyntaxLanguage: String, Sendable, CaseIterable {
    case swift, python, json, markdown, javascript, typescript
    case go, rust, ruby, shell, yaml, toml, sql, html, css
    case generic

    /// Detects the language from a file extension.
    /// - Parameter fileExtension: The file extension without leading dot.
    /// - Returns: The detected language, or `.generic` if unknown.
    public static func detect(fileExtension: String) -> SyntaxLanguage {
        switch fileExtension.lowercased() {
        case "swift": return .swift
        case "py": return .python
        case "json": return .json
        case "md", "markdown": return .markdown
        case "js": return .javascript
        case "ts", "tsx": return .typescript
        case "go": return .go
        case "rs": return .rust
        case "rb": return .ruby
        case "sh", "bash", "zsh": return .shell
        case "yml", "yaml": return .yaml
        case "toml": return .toml
        case "sql": return .sql
        case "html", "htm": return .html
        case "css": return .css
        default: return .generic
        }
    }

    /// Detects the language from a full filename.
    /// - Parameter filename: The filename (e.g. "main.swift").
    /// - Returns: The detected language, or `.generic` if unknown.
    public static func detect(filename: String) -> SyntaxLanguage {
        let ext = filename.split(separator: ".").last.map(String.init) ?? ""
        return detect(fileExtension: ext)
    }
}
