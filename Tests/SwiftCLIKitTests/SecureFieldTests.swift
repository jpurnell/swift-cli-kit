// SecureFieldTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-24.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("SecureField")
struct SecureFieldTests {

    // Typed input whose characters appear nowhere in the label, mask or border.
    private static let sample = "Zq9#"

    private func makeFrame(width: Int, height: Int = 3) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }

    private func rendered(_ field: SecureField, width: Int = 30, focused: Bool = true) -> String {
        var frame = makeFrame(width: width)
        field.render(into: &frame, focused: focused)
        return SnapshotTesting.renderPlainText(frame.cellBuffer)
    }

    private func typed(_ text: String, into field: inout SecureField) {
        for ch in text {
            _ = field.handleKey(.character(ch))
        }
    }

    private func pasteReader(_ text: String) -> KeyReader {
        let pipe = Pipe()
        let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        let writer = pipe.fileHandleForWriting
        let data = Data([0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E] + Array(text.utf8) + [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E])
        Thread {
            writer.write(data)
            writer.closeFile()
        }.start()
        return KeyReader(terminal: terminal)
    }

    private func containsAny(_ haystack: String, of secret: String) -> Bool {
        secret.unicodeScalars.contains { scalar in haystack.unicodeScalars.contains(scalar) }
    }

    // MARK: - No echo

    @Test("Typed characters render as the mask, never as themselves")
    func typedIsMasked() {
        var field = SecureField(label: "Pw")
        typed(Self.sample, into: &field)
        let output = rendered(field)
        #expect(!containsAny(output, of: Self.sample))
        #expect(output.contains("••••"))
        #expect(!output.contains("•••••"))
    }

    @Test("A bracketed paste of a 64-code-point Unicode password arrives whole and nothing echoes")
    func unicodePasteWholeNoEcho() {
        let password = BracketedPasteTests.unicodePassword
        let reader = pasteReader(password)
        var field = SecureField(label: "Pw")
        guard let key = reader.readKey() else {
            Issue.record("no key read")
            return
        }
        #expect(field.handleKey(key) == .changed)
        #expect(field.count == password.count)
        let output = rendered(field, width: 80)
        let unique = password.unicodeScalars.filter { $0 != "•" }
        #expect(!unique.contains { output.unicodeScalars.contains($0) })
        #expect(field.consume() == password)
    }

    @Test("A nil mask renders nothing for the secret")
    func nilMaskRendersNothing() {
        var field = SecureField(mask: nil)
        typed(Self.sample, into: &field)
        var frame = makeFrame(width: 30)
        field.render(into: &frame, focused: true)
        let buf = frame.cellBuffer
        let content = (1..<29).map { buf[$0, 1].character }.filter { $0 != " " }
        #expect(content.isEmpty)
    }

    @Test("The placeholder shows while empty")
    func placeholderWhenEmpty() {
        let field = SecureField(placeholder: "password")
        #expect(rendered(field).contains("password"))
    }

    @Test("A wide mask advances two columns per character")
    func wideMask() {
        var field = SecureField(mask: "🔒")
        typed("ab", into: &field)
        var frame = makeFrame(width: 20)
        field.render(into: &frame, focused: false)
        let buf = frame.cellBuffer
        #expect(buf[1, 1].character == "🔒")
        #expect(buf[3, 1].character == "🔒")
    }

    // MARK: - Reveal (P12)

    @Test("toggleReveal shows the secret and hides it again")
    func toggleReveal() {
        var field = SecureField()
        typed(Self.sample, into: &field)
        field.toggleReveal()
        #expect(field.isRevealed)
        #expect(rendered(field).contains(Self.sample))
        field.toggleReveal()
        #expect(!field.isRevealed)
        #expect(!containsAny(rendered(field), of: Self.sample))
    }

    @Test("A caller-bound reveal key toggles reveal without editing")
    func revealKey() {
        var field = SecureField()
        field.revealKey = .functionKey(2)
        typed("ab", into: &field)
        #expect(field.handleKey(.functionKey(2)) == .revealChanged(true))
        #expect(field.handleKey(.functionKey(2)) == .revealChanged(false))
        #expect(field.consume() == "ab")
    }

    @Test("Without a bound reveal key, that key is unhandled")
    func revealKeyUnbound() {
        var field = SecureField()
        #expect(field.handleKey(.functionKey(2)) == .unhandled)
        #expect(!field.isRevealed)
    }

    @Test("Revealed wide characters take two columns each")
    func revealedWideCharacters() {
        var field = SecureField()
        _ = field.handleKey(.paste("日本"))
        field.setRevealed(true)
        var frame = makeFrame(width: 20)
        field.render(into: &frame, focused: false)
        let buf = frame.cellBuffer
        #expect(buf[1, 1].character == "日")
        #expect(buf[3, 1].character == "本")
    }

    @Test("A revealed secret longer than the field shows the end, and the value is not truncated")
    func revealedLongShowsTail() {
        var field = SecureField()
        let long = String(repeating: "a", count: 40) + "XYZ"
        _ = field.handleKey(.paste(long))
        field.setRevealed(true)
        let output = rendered(field, width: 12)
        #expect(output.contains("XYZ"))
        #expect(field.consume() == long)
    }

    @Test("The visible run ends at the cursor and never exceeds the width")
    func visibleRangeLimits() {
        #expect(SecureField.visibleRange(widths: [1, 1, 1, 1], cursor: 4, width: 2) == 2..<4)
        #expect(SecureField.visibleRange(widths: [1, 1, 1, 1], cursor: 1, width: 2) == 0..<2)
        #expect(SecureField.visibleRange(widths: [2, 2], cursor: 2, width: 3) == 1..<2)
        #expect(SecureField.visibleRange(widths: [2], cursor: 1, width: 1).isEmpty)
        #expect(SecureField.visibleRange(widths: [1, 1], cursor: 9, width: 0).isEmpty)
        #expect(SecureField.visibleRange(widths: [], cursor: 0, width: 5).isEmpty)
    }

    @Test("A frame too narrow for the box draws only the label")
    func tooNarrow() {
        var field = SecureField(label: "Pw")
        typed(Self.sample, into: &field)
        field.setRevealed(true)
        let output = rendered(field, width: 4)
        #expect(!containsAny(output, of: Self.sample))
        #expect(output.hasPrefix("Pw"))
    }

    // MARK: - Unicode editing

    @Test("Backspace removes one Character, not one scalar")
    func backspaceGrapheme() {
        var field = SecureField()
        _ = field.handleKey(.paste("ae\u{301}👨‍👩‍👧"))
        #expect(field.count == 3)
        #expect(field.handleKey(.backspace) == .changed)
        #expect(field.count == 2)
        #expect(field.consume() == "ae\u{301}")
    }

    @Test("A combining mark typed after its base forms one Character")
    func combiningTyped() {
        var field = SecureField()
        _ = field.handleKey(.character("e"))
        _ = field.handleKey(.character("\u{301}"))
        #expect(field.count == 1)
        #expect(field.cursorPosition == 1)
        _ = field.handleKey(.backspace)
        #expect(field.isEmpty)
    }

    @Test("Cursor movement and mid-string insertion")
    func cursorEditing() {
        var field = SecureField()
        typed("ac", into: &field)
        _ = field.handleKey(.arrowLeft)
        _ = field.handleKey(.character("b"))
        _ = field.handleKey(.home)
        _ = field.handleKey(.delete)
        _ = field.handleKey(.end)
        _ = field.handleKey(.paste("dé"))
        #expect(field.consume() == "bcdé")
    }

    @Test("Ctrl-U and Ctrl-K kill around the cursor")
    func killKeys() {
        var field = SecureField()
        typed("abcd", into: &field)
        _ = field.handleKey(.arrowLeft)
        _ = field.handleKey(.arrowLeft)
        _ = field.handleKey(.ctrlK)
        _ = field.handleKey(.character("x"))
        _ = field.handleKey(.ctrlA)
        _ = field.handleKey(.arrowRight)
        _ = field.handleKey(.ctrlU)
        #expect(field.consume() == "bx")
    }

    @Test("Boundary keys on an empty field change nothing")
    func emptyBoundaries() {
        var field = SecureField()
        #expect(field.handleKey(.backspace) == .unhandled)
        #expect(field.handleKey(.delete) == .unhandled)
        #expect(field.handleKey(.arrowLeft) == .unhandled)
        #expect(field.handleKey(.arrowRight) == .unhandled)
        #expect(field.isEmpty)
    }

    // MARK: - No cap (P7)

    @Test("No length cap: a 10,000-character paste is kept whole")
    func noLengthCap() {
        var field = SecureField()
        let long = String(repeating: "Ω🔑x", count: 3_334)
        _ = field.handleKey(.paste(long))
        #expect(field.count == long.count)
        #expect(field.consume() == long)
    }

    // MARK: - Results

    @Test("Enter submits, Escape cancels, Tab is left to the caller")
    func results() {
        var field = SecureField()
        #expect(field.handleKey(.character("a")) == .changed)
        #expect(field.handleKey(.enter) == .submitted)
        #expect(field.handleKey(.escape) == .cancelled)
        #expect(field.handleKey(.tab) == .unhandled)
        #expect(field.consume() == "a")
    }

    // MARK: - Never logged

    @Test("description, debugDescription, Mirror and dump never contain the secret")
    func neverDescribed() {
        var field = SecureField(label: "Pw")
        typed(Self.sample, into: &field)
        field.setRevealed(true)
        var dumped = ""
        dump(field, to: &dumped)
        let views = [
            field.description,
            field.debugDescription,
            String(describing: field),
            String(reflecting: field),
            "\(field)",
            dumped,
        ]
        for view in views {
            #expect(!view.contains(Self.sample))
            #expect(!view.contains("Zq"))
            #expect(!view.contains("9#"))
        }
        let mirror = Mirror(reflecting: field)
        for child in mirror.children {
            #expect(!String(describing: child.value).contains(Self.sample))
        }
        #expect(!mirror.children.isEmpty)
    }

    // MARK: - Consume / clear

    @Test("consume returns the secret, empties the field and hides it again")
    func consumeClears() {
        var field = SecureField()
        typed(Self.sample, into: &field)
        field.setRevealed(true)
        #expect(field.consume() == Self.sample)
        #expect(field.isEmpty)
        #expect(field.cursorPosition == 0)
        #expect(!field.isRevealed)
        #expect(field.consume() == "")
    }

    @Test("clear discards the secret")
    func clearDiscards() {
        var field = SecureField()
        typed(Self.sample, into: &field)
        field.clear()
        #expect(field.isEmpty)
        #expect(!containsAny(rendered(field), of: Self.sample))
    }

    // MARK: - Through a backend

    @Test("Nothing the backend receives contains the secret")
    func backendNeverEchoes() {
        let backend = TestBackend(width: 40, height: 3)
        // The label avoids every scalar of both secrets.
        var field = SecureField(label: "Secret")
        let password = BracketedPasteTests.unicodePassword
        _ = field.handleKey(.paste(password))
        typed(Self.sample, into: &field)
        var frame = makeFrame(width: 40)
        field.render(into: &frame, focused: true)
        var renderer = DiffRenderer()
        backend.write(renderer.render(current: frame.cellBuffer, previous: nil))
        backend.submitRender(frame.cellBuffer)

        let written = backend.allWrittenOutput.joined()
        let screen = SnapshotTesting.renderPlainText(backend.currentBuffer)
        let secretScalars = (password + Self.sample).unicodeScalars.filter { $0 != "•" }
        #expect(!secretScalars.contains { screen.unicodeScalars.contains($0) })
        // ANSI output legitimately carries digits and '#'-free CSI bytes; check the
        // scalars no escape sequence contains.
        let unescapable = secretScalars.filter { !$0.isASCII || $0 == "Z" || $0 == "q" }
        #expect(!unescapable.isEmpty)
        #expect(!unescapable.contains { written.unicodeScalars.contains($0) })
        #expect(written.contains("•"))
        #expect(field.consume() == password + Self.sample)
    }
}
