// SecureField.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-24.

import Foundation

/// The outcome of a key press handled by a ``SecureField``.
///
/// Unlike ``TextFieldResult``, no case carries the field's text: a result can be
/// logged or compared without exposing the secret. Read it with
/// ``SecureField/consume()`` on ``submitted``.
public enum SecureFieldResult: Sendable, Equatable {
    /// The secret changed.
    case changed
    /// The user pressed Enter. Take the value with ``SecureField/consume()``.
    case submitted
    /// The user pressed Escape.
    case cancelled
    /// The reveal key toggled reveal; the payload is the new ``SecureField/isRevealed``.
    case revealChanged(Bool)
    /// The key was not consumed by the field, or changed nothing.
    case unhandled
}

/// A single-line input for a password or other secret that never echoes it.
///
/// Each character renders as ``mask`` — or nothing at all when `mask` is `nil` —
/// until the user asks to see it (``isRevealed``, NIST SP 800-63B's "offer to show
/// the password"). The field takes any Unicode text: editing works on whole
/// `Character`s, so Backspace removes one grapheme, and widths come from
/// ``UnicodeWidth``. There is no length cap and nothing is truncated; a
/// ``Key/paste(_:)`` — the route a password manager uses — is inserted whole.
///
/// The secret is kept out of every description: `description`,
/// `debugDescription`, `Mirror` and `dump` show the label and state, never the
/// value. Take the value once with ``consume()``, which also empties the field,
/// or discard it with ``clear()``.
///
/// ```swift
/// var field = SecureField(label: "Password")
/// field.revealKey = .functionKey(2)
/// _ = field.handleKey(.paste("correct horse"))
/// if field.handleKey(.enter) == .submitted {
///     let password = field.consume()   // field is empty again
///     _ = password
/// }
/// ```
///
/// - Important: Swift does not guarantee that freed `String` storage is zeroed,
///   so ``consume()`` and ``clear()`` drop the field's reference to the secret but
///   cannot scrub copies the runtime has made. Do not log the ``Key`` values that
///   feed the field: a key carries the raw input.
public struct SecureField: Sendable {
    /// The default mask, `•` (U+2022 BULLET).
    public static let defaultMask: Character = "•"

    /// The label displayed to the left of the input area.
    public var label: String
    /// Placeholder text shown while the field is empty.
    public var placeholder: String
    /// The character drawn for each character of the secret, or `nil` to draw nothing.
    public var mask: Character?
    /// A key that toggles ``isRevealed`` instead of editing, or `nil` (the default) for none.
    ///
    /// Choose a key that is not text, such as a function key: a bound
    /// `.character` key can no longer be typed into the field.
    public var revealKey: Key?
    /// The style applied when the field is not focused.
    public var style: CellStyle
    /// The style applied when the field is focused.
    public var focusedStyle: CellStyle

    /// Whether the secret is shown in clear instead of masked.
    public private(set) var isRevealed: Bool
    /// The cursor offset, in characters from the start.
    public private(set) var cursorPosition: Int

    private var secret: String

    /// Creates an empty secure field.
    /// - Parameters:
    ///   - label: The label text.
    ///   - placeholder: Placeholder text shown while empty.
    ///   - mask: The character drawn per secret character; `nil` draws nothing.
    ///   - style: The unfocused style.
    ///   - focusedStyle: The focused style.
    public init(
        label: String = "",
        placeholder: String = "",
        mask: Character? = SecureField.defaultMask,
        style: CellStyle = CellStyle(),
        focusedStyle: CellStyle = CellStyle(attributes: .bold)
    ) {
        self.label = label
        self.placeholder = placeholder
        self.mask = mask
        self.revealKey = nil
        self.style = style
        self.focusedStyle = focusedStyle
        self.isRevealed = false
        self.cursorPosition = 0
        self.secret = ""
    }

    /// Whether the field holds no characters.
    public var isEmpty: Bool { secret.isEmpty }

    /// The number of characters (graphemes) in the secret.
    ///
    /// A mask already shows this much; the value itself is never exposed but
    /// through ``consume()``.
    public var count: Int { secret.count }

    // MARK: - Reveal

    /// Shows the secret in clear, or masks it again.
    public mutating func toggleReveal() {
        isRevealed.toggle()
    }

    /// Sets whether the secret is shown in clear.
    /// - Parameter revealed: `true` to show the secret, `false` to mask it.
    public mutating func setRevealed(_ revealed: Bool) {
        isRevealed = revealed
    }

    // MARK: - Taking the value

    /// Returns the secret and empties the field.
    ///
    /// The field is left as new: empty, cursor at the start, masked.
    /// - Returns: The secret as entered, whole.
    public mutating func consume() -> String {
        let value = secret
        clear()
        return value
    }

    /// Discards the secret, leaving the field empty and masked.
    public mutating func clear() {
        secret = ""
        cursorPosition = 0
        isRevealed = false
    }

    // MARK: - Input

    /// Processes a key press and returns the result.
    ///
    /// Characters and pastes insert at the cursor; Backspace and Delete remove one
    /// character; Left, Right, Home/Ctrl-A and End/Ctrl-E move the cursor; Ctrl-U
    /// and Ctrl-K delete to the start and end. Enter submits, Escape cancels, and
    /// ``revealKey``, when set, toggles reveal. Every other key is unhandled.
    /// - Parameter key: The key event to handle.
    /// - Returns: A ``SecureFieldResult``, which never carries the secret.
    public mutating func handleKey(_ key: Key) -> SecureFieldResult {
        if let revealKey, key == revealKey {
            toggleReveal()
            return .revealChanged(isRevealed)
        }
        switch key {
        case .character(let ch):
            insert(String(ch))
            return .changed
        case .paste(let text):
            guard !text.isEmpty else { return .unhandled }
            insert(text)
            return .changed
        case .enter:
            return .submitted
        case .escape:
            return .cancelled
        case .backspace:
            guard cursorPosition > 0 else { return .unhandled }
            cursorPosition -= 1
            secret.remove(at: index(at: cursorPosition))
            clampCursor()
            return .changed
        case .delete:
            guard cursorPosition < secret.count else { return .unhandled }
            secret.remove(at: index(at: cursorPosition))
            clampCursor()
            return .changed
        case .ctrlU:
            guard cursorPosition > 0 else { return .unhandled }
            secret.removeSubrange(secret.startIndex..<index(at: cursorPosition))
            cursorPosition = 0
            return .changed
        case .ctrlK:
            guard cursorPosition < secret.count else { return .unhandled }
            secret.removeSubrange(index(at: cursorPosition)...)
            return .changed
        default:
            return moveCursor(for: key)
        }
    }

    private mutating func moveCursor(for key: Key) -> SecureFieldResult {
        let target: Int
        switch key {
        case .arrowLeft: target = max(0, cursorPosition - 1)
        case .arrowRight: target = min(secret.count, cursorPosition + 1)
        case .home, .ctrlA: target = 0
        case .end, .ctrlE: target = secret.count
        default: return .unhandled
        }
        cursorPosition = target
        return .unhandled
    }

    /// Inserts text at the cursor, counting the new cursor from the joined text:
    /// a combining mark merges into the character before it.
    private mutating func insert(_ text: String) {
        let split = index(at: cursorPosition)
        let head = String(secret[..<split]) + text
        secret = head + String(secret[split...])
        cursorPosition = min(head.count, secret.count)
    }

    /// Keeps the cursor inside the text after a removal lets two characters merge.
    private mutating func clampCursor() {
        cursorPosition = min(cursorPosition, secret.count)
    }

    private func index(at offset: Int) -> String.Index {
        secret.index(secret.startIndex, offsetBy: min(max(offset, 0), secret.count))
    }

    // MARK: - Rendering

    /// Renders the field into the given frame: label, box, and the masked or
    /// revealed secret.
    ///
    /// Masked, each character draws as ``mask`` (nothing when `nil`); revealed,
    /// as itself. When the text is wider than the box, the part ending at the
    /// cursor is shown; the stored value is never shortened.
    /// - Parameters:
    ///   - frame: The frame to render into.
    ///   - focused: Whether this field currently has focus.
    public func render(into frame: inout Frame, focused: Bool) {
        let activeStyle = focused ? focusedStyle : style
        guard var content = InputFieldChrome.draw(label: label, style: activeStyle, into: &frame) else { return }
        let width = content.rect.width

        guard !secret.isEmpty else {
            content.writeText(
                String(placeholder.prefix(width)),
                x: 0, y: 0,
                fg: activeStyle.fg, bg: activeStyle.bg,
                attributes: .dim
            )
            return
        }

        let glyphs = displayedGlyphs()
        guard !glyphs.isEmpty else { return }
        let visible = Self.visibleRange(widths: glyphs.map(Self.columns), cursor: cursorPosition, width: width)
        content.writeText(
            String(glyphs[visible]),
            x: 0, y: 0,
            fg: activeStyle.fg, bg: activeStyle.bg,
            attributes: activeStyle.attributes
        )
    }

    /// The characters to draw: the secret when revealed, one mask per character
    /// otherwise, none for a `nil` mask.
    private func displayedGlyphs() -> [Character] {
        if isRevealed {
            return Array(secret)
        }
        guard let mask else { return [] }
        return Array(repeating: mask, count: secret.count)
    }

    /// The columns a character occupies, as ``Frame/writeText(_:x:y:fg:bg:attributes:)`` advances.
    private static func columns(_ character: Character) -> Int {
        max(UnicodeWidth.width(of: character), 1)
    }

    /// The run of glyphs that fits `width` columns and ends at the cursor, extended
    /// past the cursor while room remains.
    static func visibleRange(widths: [Int], cursor: Int, width: Int) -> Range<Int> {
        let end = min(max(cursor, 0), widths.count)
        var start = end
        var used = 0
        while start > 0, used + widths[start - 1] <= width {
            start -= 1
            used += widths[start]
        }
        var stop = end
        while stop < widths.count, used + widths[stop] <= width {
            used += widths[stop]
            stop += 1
        }
        return start..<stop
    }
}

// MARK: - Never describe the secret

extension SecureField: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// A description that names the field and its state, never the secret or its length.
    public var description: String {
        "SecureField(label: \(String(reflecting: label)), isEmpty: \(isEmpty), isRevealed: \(isRevealed))"
    }

    /// The same as ``description``: the secret is not shown even when debugging.
    public var debugDescription: String { description }

    /// A mirror without the secret or its length, so `dump` and debuggers cannot show them.
    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "label": label,
                "placeholder": placeholder,
                "isEmpty": isEmpty,
                "isRevealed": isRevealed,
            ],
            displayStyle: .struct
        )
    }
}
